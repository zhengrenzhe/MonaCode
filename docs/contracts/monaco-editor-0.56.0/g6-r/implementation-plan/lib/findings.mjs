// G6-R findings module.
// Owns the ONE finding shape and sort order used by every later module.
// A Finding is the single canonical record emitted by the execution-plan
// validator (and every downstream verifier) for one detected contract defect.

/**
 * Canonical finding IDs, listed in the canonical sort order.
 * sortFindings orders results by this sequence, then by path, then by message.
 * Every module that emits findings MUST use ids drawn from this set and MUST
 * sort via sortFindings so output is deterministic and comparable.
 */
export const FINDING_IDS = [
  'PLAN_TYPE',
  'PLAN_STAGE_SET',
  'PLAN_STAGE_ORDER',
  'PLAN_STAGE_COMPATIBILITY',
  'PLAN_STAGE_STEP_INVALID',
  'PLAN_COMMAND_SHAPE',
  'PLAN_PATH_AVAILABILITY',
  'PLAN_TEST_CONTRACT',
  'PLAN_SCAFFOLD',
  'PLAN_SOURCE_ACQUISITION',
  'PLAN_SOURCE_ARCHIVE_INVALID',
  'PLAN_LEAF_SELECTION',
  'PLAN_WORKSPACE',
  'PLAN_PRODUCT_COMMIT_CONTRACT',
  'PLAN_EVIDENCE_CONTRACT',
  'PLAN_SCHEMA_ADDITIONAL_PROPERTY',
];

const ORDER = new Map(FINDING_IDS.map((id, i) => [id, i]));

/**
 * Construct a Finding. `taskID` defaults to null (plan-level defects that are
 * not attributable to a single task record).
 * @returns {{id:string,category:string,taskID:(string|null),path:string,message:string}}
 */
export function makeFinding({ id, category, taskID, path, message }) {
  return {
    id,
    category,
    taskID: taskID === undefined ? null : taskID,
    path,
    message,
  };
}

/**
 * Return a new array of findings sorted by the canonical finding-ID order,
 * then by JSON pointer path, then by message. Stable and deterministic.
 * @param {ReturnType<typeof makeFinding>[]} findings
 */
export function sortFindings(findings) {
  return [...findings].sort((a, b) => {
    const oi = ORDER.has(a.id) ? ORDER.get(a.id) : FINDING_IDS.length;
    const oj = ORDER.has(b.id) ? ORDER.get(b.id) : FINDING_IDS.length;
    if (oi !== oj) return oi - oj;
    if (a.path !== b.path) return a.path < b.path ? -1 : 1;
    const ma = a.message ?? '';
    const mb = b.message ?? '';
    return ma < mb ? -1 : ma > mb ? 1 : 0;
  });
}
