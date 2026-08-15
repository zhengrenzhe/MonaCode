import { compareFindings, finding } from './findings.mjs';

const FORBIDDEN_CORE_TOKENS = [
  'import AppKit',
  'import CoreText',
  'import CoreGraphics',
  'import Metal',
  'NSView',
  'CGPoint',
  'NSEvent',
  'NSRange',
  'NSPasteboard',
  'Process'
];

const sorted = (values) => [...values].sort((left, right) => left.localeCompare(right, 'en'));
const equalStrings = (left, right) => JSON.stringify(sorted(left ?? [])) === JSON.stringify(sorted(right ?? []));

function taskMap(plan) {
  return new Map((plan.tasks ?? []).map((task) => [task.id, task]));
}

function transitivelyDepends(plan, taskID, dependencyID) {
  const byId = taskMap(plan);
  const pending = [...(byId.get(taskID)?.dependencies ?? [])];
  const visited = new Set();
  while (pending.length !== 0) {
    const id = pending.pop();
    if (id === dependencyID) return true;
    if (visited.has(id)) continue;
    visited.add(id);
    pending.push(...(byId.get(id)?.dependencies ?? []));
  }
  return false;
}

export function auditPackageGraph(plan, contract) {
  const findings = [];
  const expectedProducts = new Map([
    ['MonaCode', []],
    ['MonaCodeAppKit', ['MonaCode']],
    ['MonaCodeSwiftUI', ['MonaCode', 'MonaCodeAppKit']]
  ]);
  const products = new Map((plan.packageGraph?.products ?? []).map((row) => [row.name, row.dependencies]));
  if (!equalStrings(products.keys(), expectedProducts.keys())) {
    findings.push(finding('PLAN_PACKAGE_GRAPH_MISMATCH', 'products', 'public product set differs from contract'));
  } else {
    for (const [name, dependencies] of expectedProducts) {
      if (!equalStrings(products.get(name), dependencies)) {
        findings.push(finding('PLAN_PACKAGE_GRAPH_MISMATCH', name, 'public product dependencies differ from contract'));
      }
    }
  }

  const expectedTargets = new Set(contract.deliveryScope.requiredNonProductTargets);
  const targets = new Map((plan.packageGraph?.nonProductTargets ?? []).map((row) => [row.name, row.dependencies]));
  if (!equalStrings(targets.keys(), expectedTargets)) {
    findings.push(finding('PLAN_PACKAGE_GRAPH_MISMATCH', 'nonProductTargets', 'required target set differs from contract'));
  }
  const sampleDependencies = targets.get('sample-macOS-host');
  if (sampleDependencies && !equalStrings(sampleDependencies, [...expectedProducts.keys()])) {
    findings.push(finding('PLAN_PACKAGE_GRAPH_MISMATCH', 'sample-macOS-host', 'sample host must depend on all three products'));
  }
  const fixtures = (plan.packageGraph?.resources ?? []).find((row) => row.name === 'DifferentialFixtures');
  if (!fixtures || fixtures.path !== 'Tests/Fixtures/DifferentialFixtures' || fixtures.isTarget !== false) {
    findings.push(finding('PLAN_PACKAGE_GRAPH_MISMATCH', 'DifferentialFixtures', 'fixture resource mapping differs from contract'));
  }
  return findings.sort(compareFindings);
}

export function auditCandidateOrder(plan) {
  const findings = [];
  const tasks = plan.tasks ?? [];
  const candidateArtifacts = plan.candidateArtifacts ?? [];
  const finalizerByArtifact = new Map();
  for (const artifact of candidateArtifacts) {
    const token = `candidate-finalizer:${artifact}`;
    const finalizers = tasks.filter((task) => task.ownership?.includes(token));
    if (finalizers.length !== 1) {
      findings.push(finding('PLAN_CANDIDATE_ORDER', artifact, `expected one finalizer, found ${finalizers.length}`));
    } else {
      finalizerByArtifact.set(artifact, finalizers[0]);
    }
  }

  const publicClosure = tasks.filter((task) => task.ownership?.includes('public-api-closure'));
  const declarationFinalizer = finalizerByArtifact.get('MonaNativeDeclarationManifest.json');
  if (
    declarationFinalizer
    && (publicClosure.length !== 1 || !transitivelyDepends(plan, declarationFinalizer.id, publicClosure[0].id))
  ) {
    findings.push(finding(
      'PLAN_CANDIDATE_ORDER',
      'MonaNativeDeclarationManifest.json',
      'native declaration finalizer must follow public API closure'
    ));
  }

  for (const task of tasks) {
    for (const owner of task.ownership ?? []) {
      if (!owner.startsWith('candidate-consumer:')) continue;
      const artifact = owner.slice('candidate-consumer:'.length);
      const finalizer = finalizerByArtifact.get(artifact);
      if (finalizer && !transitivelyDepends(plan, task.id, finalizer.id)) {
        findings.push(finding('PLAN_CANDIDATE_ORDER', `${task.id}:${artifact}`, 'consumer does not follow finalizer'));
      }
    }
  }
  return findings.sort(compareFindings);
}

export function auditMetalTrigger(plan) {
  const findings = [];
  const tasks = plan.tasks ?? [];
  const coreGraphics = tasks.filter((task) => task.ownership?.includes('renderer:core-graphics-complete'));
  const gates = tasks.filter((task) => task.ownership?.includes('renderer:decision-gate'));
  const metalTasks = tasks.filter((task) => task.ownership?.includes('renderer:metal-conditional'));
  if (coreGraphics.length !== 1 || gates.length !== 1 || metalTasks.length !== 1) {
    findings.push(finding(
      'PLAN_METAL_TRIGGER_SCOPE',
      'rendererDecision',
      `expected one Core Graphics completion, gate, and conditional Metal task; found ${coreGraphics.length}/${gates.length}/${metalTasks.length}`
    ));
    return findings;
  }
  const gate = gates[0];
  const metal = metalTasks[0];
  if (!transitivelyDepends(plan, gate.id, coreGraphics[0].id)) {
    findings.push(finding('PLAN_METAL_TRIGGER_SCOPE', gate.id, 'renderer gate does not follow complete Core Graphics'));
  }
  if (metal.phase !== '03' || !transitivelyDepends(plan, metal.id, gate.id)) {
    findings.push(finding('PLAN_METAL_TRIGGER_SCOPE', metal.id, 'conditional Metal task must follow the Phase 03 gate'));
  }
  const triggerOwners = (gate.ownership ?? []).filter((owner) => (
    owner.startsWith('renderer-metric:') || owner.startsWith('performanceWorkload:')
  ));
  const allowedTriggerOwners = new Set(['renderer-metric:C03', 'renderer-metric:C08']);
  if (
    triggerOwners.length !== allowedTriggerOwners.size
    || triggerOwners.some((owner) => !allowedTriggerOwners.has(owner))
  ) {
    findings.push(finding('PLAN_METAL_TRIGGER_SCOPE', gate.id, triggerOwners.join(',')));
  }
  for (const task of tasks.filter((candidate) => Number(candidate.phase) > 3 && candidate.files?.productTarget !== null)) {
    const sourcePaths = [...(task.files?.create ?? []), ...(task.files?.modify ?? [])];
    if (sourcePaths.some((sourcePath) => /metal/i.test(sourcePath))) {
      findings.push(finding('PLAN_METAL_TRIGGER_SCOPE', task.id, 'renderer source is created after Phase 03'));
    }
  }
  return findings.sort(compareFindings);
}

export function auditBoundaries(plan, contract) {
  const findings = auditPackageGraph(plan, contract);
  for (const task of (plan.tasks ?? []).filter((candidate) => candidate.files?.productTarget === 'MonaCode')) {
    const productionText = JSON.stringify({
      create: task.files.create,
      modify: task.files.modify,
      produces: task.interfaces?.produces,
      operations: task.implementation?.operations
    });
    for (const token of FORBIDDEN_CORE_TOKENS) {
      if (productionText.includes(token)) {
        findings.push(finding('PLAN_FORBIDDEN_CORE_IMPORT', task.id, token));
      }
    }
  }
  return findings.concat(auditCandidateOrder(plan), auditMetalTrigger(plan)).sort(compareFindings);
}
