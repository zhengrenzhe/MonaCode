// G6-R coverage audit (ported from G5-R without cross-directory imports).
// Proves the plan's ownership table maps every retained contract identity
// exactly once to a single implementation owner + at least one test owner,
// names no unknown identity, and carries no disposition-only identity with a
// product or test owner. Adapted to the G6-R Finding shape (makeFinding) and
// the G6-R plan's `task.id` identifier.

import { makeFinding, sortFindings } from './findings.mjs';
import { identityKey } from './inventory.mjs';

const isArr = (v) => Array.isArray(v);

/**
 * Audit the plan's ownership coverage against the contract inventory.
 * @param {{identities:Array}} inventory
 * @param {{tasks?:Array<{id:string}>, ownership?:Array<{kind:string,id:string,disposition?:string,implementationOwners?:string[],testOwners?:string[]}>}} plan
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function auditOwnership(inventory, plan) {
  const findings = [];
  const taskIDs = new Set((plan.tasks ?? []).map((t) => t.id));
  const inventoryByKey = new Map((inventory.identities ?? []).map((i) => [identityKey(i), i]));
  const ownershipByKey = new Map();

  for (const row of plan.ownership ?? []) {
    const key = identityKey(row);
    if (ownershipByKey.has(key)) {
      findings.push(makeFinding({
        id: 'PLAN_DUPLICATE_OWNERSHIP_ROW', category: 'coverage', taskID: null,
        path: '/ownership', message: `ownership identity ${key} appears more than once`,
      }));
      continue;
    }
    ownershipByKey.set(key, row);
    if (!inventoryByKey.has(key)) {
      findings.push(makeFinding({
        id: 'PLAN_OWNERSHIP_IDENTITY_UNKNOWN', category: 'coverage', taskID: null,
        path: '/ownership', message: `ownership identity ${key} is absent from contract inventory`,
      }));
    }
  }

  for (const identity of inventory.identities ?? []) {
    const key = identityKey(identity);
    const row = ownershipByKey.get(key);
    if (!row) {
      findings.push(makeFinding({
        id: identity.retained ? 'PLAN_RETAINED_IDENTITY_UNMAPPED' : 'PLAN_DISPOSITION_IDENTITY_UNMAPPED',
        category: 'coverage', taskID: null, path: '/ownership',
        message: `${identity.retained ? 'retained' : 'disposition'} identity ${key} (${identity.disposition}) has no ownership row`,
      }));
      continue;
    }
    if (row.disposition !== identity.disposition) {
      findings.push(makeFinding({
        id: 'PLAN_DISPOSITION_MISMATCH', category: 'coverage', taskID: null,
        path: '/ownership', message: `${key} disposition ${row.disposition} != ${identity.disposition}`,
      }));
    }
    const implementationOwners = row.implementationOwners ?? [];
    const testOwners = row.testOwners ?? [];
    if (identity.retained) {
      if (implementationOwners.length === 0) {
        findings.push(makeFinding({
          id: 'PLAN_IMPLEMENTATION_OWNER_MISSING', category: 'coverage', taskID: null,
          path: '/ownership', message: `retained identity ${key} has no implementation owner`,
        }));
      } else if (implementationOwners.length !== 1) {
        findings.push(makeFinding({
          id: 'PLAN_DUPLICATE_IMPLEMENTATION_OWNER', category: 'coverage', taskID: null,
          path: '/ownership', message: `${key} has implementation owners ${implementationOwners.join(',')}`,
        }));
      }
      if (testOwners.length === 0) {
        findings.push(makeFinding({
          id: 'PLAN_TEST_OWNER_MISSING', category: 'coverage', taskID: null,
          path: '/ownership', message: `retained identity ${key} has no test owner`,
        }));
      }
    } else if (implementationOwners.length !== 0 || testOwners.length !== 0) {
      findings.push(makeFinding({
        id: 'PLAN_CUT_IDENTITY_OWNED', category: 'coverage', taskID: null,
        path: '/ownership', message: `non-production identity ${key} has a product or test owner`,
      }));
    }
    for (const owner of [...implementationOwners, ...testOwners]) {
      if (!taskIDs.has(owner)) {
        findings.push(makeFinding({
          id: 'PLAN_OWNER_TASK_ABSENT', category: 'coverage', taskID: null,
          path: '/ownership', message: `${key} owner ${owner} is not a task`,
        }));
      }
    }
  }
  return sortFindings(findings);
}
