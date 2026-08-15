import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { auditBoundaries } from './boundaries.mjs';
import { auditOwnership } from './coverage.mjs';
import { auditEvidence } from './evidence.mjs';
import { auditExecutability } from './executability.mjs';
import { compareFindings } from './findings.mjs';
import { auditTaskGraph, topologicalOrder } from './graph.mjs';
import { auditMarkdown } from './markdown.mjs';
import { validatePlanSchema } from './schema.mjs';

const identityKey = (row) => `${row.kind}:${row.id}`;
const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');

function selectedPhase(plan, phaseID) {
  if (phaseID === null) return plan;
  return {
    ...plan,
    phases: (plan.phases ?? []).filter((phase) => phase.id === phaseID)
  };
}

function selectedInventory(inventory, plan, phaseID) {
  if (phaseID === null) return inventory;
  const declaredKeys = new Set((plan.ownership ?? []).map(identityKey));
  const identities = inventory.identities.filter((identity) => declaredKeys.has(identityKey(identity)));
  return {
    ...inventory,
    identities,
    retained: identities.filter((identity) => identity.retained),
    dispositionOnly: identities.filter((identity) => !identity.retained)
  };
}

function phaseBoundaryFindings(plan, contract, phaseID) {
  if (phaseID === null) return auditBoundaries(plan, contract);
  const phaseNumber = Number(phaseID);
  const boundaryPlan = phaseID === '08'
    ? {
        ...plan,
        candidateArtifacts: (plan.candidateArtifacts ?? []).filter((artifact) => artifact !== 'QEnvironmentID.json')
      }
    : plan;
  const all = auditBoundaries(boundaryPlan, contract);
  return all.filter((row) => {
    if (row.id === 'PLAN_METAL_TRIGGER_SCOPE') return phaseNumber >= 3;
    if (row.id === 'PLAN_CANDIDATE_ORDER') return phaseNumber >= 8;
    return true;
  });
}

function documentHashes(plan, planDirectory, phaseID) {
  return (plan.phases ?? [])
    .filter((phase) => phaseID === null || phase.id === phaseID)
    .map((phase) => phase.document)
    .sort((left, right) => left.localeCompare(right, 'en'))
    .filter((document) => fs.existsSync(path.resolve(planDirectory, document)))
    .map((document) => ({
      path: document,
      sha256: sha256(fs.readFileSync(path.resolve(planDirectory, document)))
    }));
}

function resultFromGroups({
  plan,
  inventory,
  planDirectory,
  phaseID,
  schemaFindings,
  graphFindings,
  markdownFindings,
  coverageFindings,
  boundaryFindings,
  evidenceFindings,
  executabilityFindings
}) {
  const findings = [
    ...schemaFindings,
    ...graphFindings,
    ...markdownFindings,
    ...coverageFindings,
    ...boundaryFindings,
    ...evidenceFindings,
    ...executabilityFindings
  ].sort(compareFindings);
  const environmentFailures = evidenceFindings.filter((row) => row.id === 'PLAN_ENVIRONMENT_MISMATCH').length;
  const dependencyFailures = graphFindings.length;
  const markerFailures = markdownFindings.length;
  const ownershipByKey = new Map((plan.ownership ?? []).map((row) => [identityKey(row), row]));
  const retainedFeatures = inventory.identities.filter((identity) => identity.kind === 'feature' && identity.retained);
  const mappedRetainedFeatures = retainedFeatures.filter((identity) => (
    (ownershipByKey.get(identityKey(identity))?.implementationOwners?.length ?? 0) === 1
    && (ownershipByKey.get(identityKey(identity))?.testOwners?.length ?? 0) > 0
  ));
  const nativeColorizePaths = [
    'editor.colorize',
    'editor.colorizeElement',
    'editor.colorizeModelLine'
  ];
  const mappedNativeColorizePaths = nativeColorizePaths.filter((id) => {
    const row = ownershipByKey.get(`publicPath:${id}`);
    return (row?.implementationOwners?.length ?? 0) === 1 && (row?.testOwners?.length ?? 0) > 0;
  });
  return {
    status: findings.length === 0 ? 'pass' : 'fail',
    findingCount: findings.length,
    phase: phaseID,
    findings,
    counts: {
      schemaFailures: schemaFindings.length,
      dependencyFailures,
      markerFailures,
      coverageFailures: coverageFindings.length,
      boundaryFailures: boundaryFindings.length,
      evidenceFailures: evidenceFindings.length - environmentFailures,
      environmentFailures,
      executabilityFailures: executabilityFindings.length
    },
    coverage: {
      contractIdentities: inventory.identities.length,
      retainedIdentities: inventory.retained.length,
      dispositionOnlyIdentities: inventory.dispositionOnly.length,
      ownershipRows: (plan.ownership ?? []).length,
      retainedFeatureIds: retainedFeatures.length,
      missingRetainedFeatureIds: retainedFeatures.length - mappedRetainedFeatures.length,
      nativeColorizeReplacements: mappedNativeColorizePaths.length
    },
    topologicalOrder: graphFindings.length === 0 ? topologicalOrder(plan.tasks ?? []) : [],
    documentHashes: documentHashes(plan, planDirectory, phaseID)
  };
}

export function auditPlan({ contract, plan, inventory, planDirectory, mode = {} }) {
  const phaseID = mode.phase ?? null;
  const schemaFindings = validatePlanSchema(plan);
  const graphFindings = auditTaskGraph(plan);
  const markdownFindings = auditMarkdown(selectedPhase(plan, phaseID), planDirectory);
  const coverageFindings = auditOwnership(selectedInventory(inventory, plan, phaseID), plan);
  const boundaryFindings = phaseBoundaryFindings(plan, contract, phaseID);
  const evidenceFindings = auditEvidence(plan, contract);
  const executabilityFindings = auditExecutability(plan);
  return resultFromGroups({
    plan,
    inventory,
    planDirectory,
    phaseID,
    schemaFindings,
    graphFindings,
    markdownFindings,
    coverageFindings,
    boundaryFindings,
    evidenceFindings,
    executabilityFindings
  });
}

function ownershipFixturePlan(inventory) {
  return {
    tasks: [{ id: 'P00-T001' }, { id: 'P00-T002' }],
    ownership: inventory.identities.map((identity) => ({
      kind: identity.kind,
      id: identity.id,
      disposition: identity.disposition,
      implementationOwners: identity.retained ? ['P00-T001'] : [],
      testOwners: identity.retained ? ['P00-T001'] : []
    }))
  };
}

function applyOwnershipMutation(plan, mutation) {
  const matches = (row) => row.kind === mutation.kind && row.id === mutation.id;
  if (mutation.mutation === 'remove-row') {
    plan.ownership = plan.ownership.filter((row) => !matches(row));
  } else if (mutation.mutation === 'add-implementation-owner') {
    plan.ownership.find(matches).implementationOwners.push(mutation.owner);
  } else if (mutation.mutation === 'own-cut-row') {
    plan.ownership.find(matches).implementationOwners = [mutation.owner];
  } else {
    throw new Error(`unknown ownership fixture mutation: ${mutation.mutation}`);
  }
}

function boundaryTask(id, phase, dependencies, ownership, productTarget = null) {
  return {
    id,
    phase,
    dependencies,
    ownership,
    files: {
      productTarget,
      create: productTarget === null ? [] : [`Sources/${productTarget}/${id}.swift`],
      modify: [],
      test: [`Tests/PlanFixtures/${id}.swift`]
    },
    interfaces: { consumes: dependencies, produces: ownership },
    implementation: { operations: [`Implement ${id} within its declared boundary.`] },
    evidence: [`artifacts/acceptance-evidence/g5-r/${phase}/${id}.json`]
  };
}

function boundaryFixturePlan(seedPlan) {
  const plan = structuredClone(seedPlan);
  plan.tasks = [
    boundaryTask('P01-T001', '01', [], ['model:piece-tree'], 'MonaCode'),
    boundaryTask('P03-T001', '03', ['P01-T001'], ['renderer:core-graphics-complete'], 'MonaCodeAppKit'),
    boundaryTask('P03-T002', '03', ['P03-T001'], [
      'renderer:decision-gate',
      'renderer-metric:C03',
      'renderer-metric:C08'
    ]),
    boundaryTask('P03-T003', '03', ['P03-T002'], ['renderer:metal-conditional'], 'MonaCodeAppKit'),
    boundaryTask('P07-T001', '07', ['P03-T003'], ['public-api-closure']),
    boundaryTask('P08-T010', '08', ['P07-T001'], ['candidate-finalizer:MonaNativeDeclarationManifest.json']),
    boundaryTask('P08-T011', '08', ['P07-T001'], ['candidate-finalizer:MonaRegExpUnicodeManifest.json']),
    boundaryTask('P08-T012', '08', ['P07-T001'], ['candidate-finalizer:MonaEnvironmentManifest.json']),
    boundaryTask('P08-T013', '08', ['P07-T001'], ['candidate-finalizer:MonaSourceClosureManifest.json']),
    boundaryTask('P08-T014', '08', ['P07-T001'], ['candidate-finalizer:MonaCacheManifest.json']),
    boundaryTask('P08-T015', '08', ['P08-T010', 'P08-T011', 'P08-T012', 'P08-T013', 'P08-T014'], [
      'candidate-finalizer:MonaDistributionManifest.json'
    ]),
    boundaryTask('P09-T001', '09', ['P08-T015'], ['candidate-finalizer:QEnvironmentID.json']),
    boundaryTask('P09-T020', '09', [
      'P08-T010', 'P08-T011', 'P08-T012', 'P08-T013', 'P08-T014', 'P08-T015', 'P09-T001'
    ], plan.candidateArtifacts.map((name) => `candidate-consumer:${name}`))
  ];
  return plan;
}

function applyBoundaryMutation(plan, row) {
  if (row.mutation === 'core-operation') {
    plan.tasks.find((task) => task.id === row.task).implementation.operations.push(row.value);
  } else if (row.mutation === 'replace-product-dependencies') {
    plan.packageGraph.products.find((product) => product.name === row.product).dependencies = row.value;
  } else if (row.mutation === 'remove-consumer-dependency') {
    const consumer = plan.tasks.find((task) => task.id === row.consumer);
    consumer.dependencies = consumer.dependencies.filter((dependency) => dependency !== row.finalizer);
  } else if (row.mutation === 'plan-state') {
    plan.planState = row.value;
  } else if (row.mutation === 'macos-build') {
    plan.qualificationEnvironment.macOSBuild = row.value;
  } else if (row.mutation === 'add-metal-gate-owner') {
    plan.tasks.find((task) => task.id === row.task).ownership.push(row.value);
  } else if (row.mutation === 'acceptance-before-distribution') {
    plan.tasks.find((task) => task.id === row.task).dependencies = row.value;
  } else if (row.mutation === 'add-source-path') {
    plan.tasks.find((task) => task.id === row.task).files.create.push(row.value);
  } else if (row.mutation === 'replace-global-constraint') {
    const index = plan.globalConstraints.findIndex((value) => value.includes(row.match));
    if (index === -1) throw new Error(`global constraint fixture match absent: ${row.match}`);
    plan.globalConstraints[index] = plan.globalConstraints[index].replace(row.match, row.value);
  } else {
    throw new Error(`unknown boundary fixture mutation: ${row.mutation}`);
  }
}

function applyExecutabilityMutation(plan, row) {
  const task = plan.tasks.find((candidate) => candidate.id === row.task);
  if (row.mutation === 'evidence-path') {
    task.evidence[0] = row.value;
  } else if (row.mutation === 'qualification-property') {
    plan.qualificationEnvironment[row.key] = row.value;
  } else if (row.mutation === 'add-modify-path') {
    task.files.modify.push(row.value);
    task.commitBoundary.push(row.value);
  } else if (row.mutation === 'add-interface-consume') {
    task.interfaces.consumes.push(row.value);
  } else if (row.mutation === 'replace-command') {
    task[row.stage][row.index].run = row.value;
  } else if (row.mutation === 'remove-dependency') {
    task.dependencies = task.dependencies.filter((dependency) => dependency !== row.value);
  } else {
    throw new Error(`unknown executability fixture mutation: ${row.mutation}`);
  }
}

function markdownFixtureFindings(fixture) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'monacode-plan-fixture-'));
  try {
    for (const [relativePath, contents] of Object.entries(fixture.documents)) {
      const file = path.join(directory, relativePath);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, contents);
    }
    return auditMarkdown(fixture.plan, directory);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

export function auditFixture({ fixture, contract, seedPlan, inventory }) {
  let findings;
  if (Array.isArray(fixture.tasks)) {
    findings = auditTaskGraph({ tasks: fixture.tasks });
  } else if (fixture.documents) {
    findings = markdownFixtureFindings(fixture);
  } else if (['remove-row', 'add-implementation-owner', 'own-cut-row'].includes(fixture.mutation)) {
    const plan = ownershipFixturePlan(inventory);
    applyOwnershipMutation(plan, fixture);
    findings = auditOwnership(inventory, plan);
  } else if ([
    'evidence-path',
    'qualification-property',
    'add-modify-path',
    'add-interface-consume',
    'replace-command',
    'remove-dependency'
  ].includes(fixture.mutation)) {
    const plan = structuredClone(seedPlan);
    applyExecutabilityMutation(plan, fixture);
    findings = [
      ...auditEvidence(plan, contract),
      ...auditExecutability(plan)
    ].sort(compareFindings);
  } else {
    const plan = [
      'acceptance-before-distribution',
      'add-source-path',
      'replace-global-constraint'
    ].includes(fixture.mutation)
      ? structuredClone(seedPlan)
      : boundaryFixturePlan(seedPlan);
    applyBoundaryMutation(plan, fixture);
    findings = [
      ...auditBoundaries(plan, contract),
      ...auditEvidence(plan, contract)
    ].sort(compareFindings);
  }
  findings.sort(compareFindings);
  return {
    status: findings.length === 0 ? 'pass' : 'fail',
    findingCount: findings.length,
    findings
  };
}
