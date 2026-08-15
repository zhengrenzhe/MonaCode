import { compareFindings, finding } from './findings.mjs';

const identityKey = (row) => `${row.kind}:${row.id}`;

export function auditOwnership(inventory, plan) {
  const findings = [];
  const taskIDs = new Set((plan.tasks ?? []).map((task) => task.id));
  const inventoryByKey = new Map(inventory.identities.map((identity) => [identityKey(identity), identity]));
  const ownershipByKey = new Map();

  for (const row of plan.ownership ?? []) {
    const key = identityKey(row);
    if (ownershipByKey.has(key)) {
      findings.push(finding('PLAN_DUPLICATE_OWNERSHIP_ROW', key, 'ownership identity appears more than once'));
      continue;
    }
    ownershipByKey.set(key, row);
    if (!inventoryByKey.has(key)) {
      findings.push(finding('PLAN_OWNERSHIP_IDENTITY_UNKNOWN', key, 'ownership identity is absent from contract inventory'));
    }
  }

  for (const identity of inventory.identities) {
    const key = identityKey(identity);
    const row = ownershipByKey.get(key);
    if (!row) {
      findings.push(finding(
        identity.retained ? 'PLAN_RETAINED_IDENTITY_UNMAPPED' : 'PLAN_DISPOSITION_IDENTITY_UNMAPPED',
        key,
        identity.disposition
      ));
      continue;
    }
    if (row.disposition !== identity.disposition) {
      findings.push(finding('PLAN_DISPOSITION_MISMATCH', key, `${row.disposition} != ${identity.disposition}`));
    }
    const implementationOwners = row.implementationOwners ?? [];
    const testOwners = row.testOwners ?? [];
    if (identity.retained) {
      if (implementationOwners.length === 0) {
        findings.push(finding('PLAN_IMPLEMENTATION_OWNER_MISSING', key, 'retained identity has no implementation owner'));
      } else if (implementationOwners.length !== 1) {
        findings.push(finding('PLAN_DUPLICATE_IMPLEMENTATION_OWNER', key, implementationOwners.join(',')));
      }
      if (testOwners.length === 0) {
        findings.push(finding('PLAN_TEST_OWNER_MISSING', key, 'retained identity has no test owner'));
      }
    } else if (implementationOwners.length !== 0 || testOwners.length !== 0) {
      findings.push(finding('PLAN_CUT_IDENTITY_OWNED', key, 'non-production identity has a product or test owner'));
    }
    for (const owner of [...implementationOwners, ...testOwners]) {
      if (!taskIDs.has(owner)) findings.push(finding('PLAN_OWNER_TASK_ABSENT', key, owner));
    }
  }
  return findings.sort(compareFindings);
}
