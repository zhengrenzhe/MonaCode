// G6-R findings module.
// Owns the ONE finding shape and sort order used by every later module.
// A Finding is the single canonical record emitted by the execution-plan
// validator (and every downstream verifier) for one detected contract defect.
//
// Task 26 extends the declared ID set with the ported G5-R audit categories
// (graph, coverage, boundary, Markdown, ambiguity) and the execution-readiness
// categories (verification-command, executor, source-acquisition, path,
// file-state, interface, mutation, task-workspace, product-commit,
// evidence-commit, commit-lifecycle, evidence, scope, payload-inventory,
// checksum-index, adoption-selector) so the integrated audit's output is
// deterministic and comparable across runs. IDs unknown to this list sort
// after all declared IDs, preserving insertion order (stable sort).

export const FINDING_IDS = [
  // Task 3 structural/semantic plan IDs (retained).
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
  // Task 26 ported G5-R graph category.
  'PLAN_DEPENDENCY_ABSENT',
  'PLAN_DEPENDENCY_DUPLICATE',
  'PLAN_DEPENDENCY_CYCLE',
  // Task 26 ported G5-R coverage category.
  'PLAN_DUPLICATE_OWNERSHIP_ROW',
  'PLAN_OWNERSHIP_IDENTITY_UNKNOWN',
  'PLAN_RETAINED_IDENTITY_UNMAPPED',
  'PLAN_DISPOSITION_IDENTITY_UNMAPPED',
  'PLAN_DISPOSITION_MISMATCH',
  'PLAN_IMPLEMENTATION_OWNER_MISSING',
  'PLAN_DUPLICATE_IMPLEMENTATION_OWNER',
  'PLAN_TEST_OWNER_MISSING',
  'PLAN_CUT_IDENTITY_OWNED',
  'PLAN_OWNER_TASK_ABSENT',
  // Task 26 ported G5-R boundary category.
  'PLAN_PACKAGE_GRAPH_MISMATCH',
  'PLAN_GLOBAL_CONSTRAINT_MISMATCH',
  'PLAN_FORBIDDEN_PRODUCT_PATH',
  'PLAN_FORBIDDEN_CORE_IMPORT',
  'PLAN_METAL_TRIGGER_SCOPE',
  'PLAN_CANDIDATE_ORDER',
  'PLAN_ACCEPTANCE_ORDER',
  // Task 26 ported G5-R Markdown category.
  'PLAN_PHASE_DOCUMENT_MISSING',
  'PLAN_MARKDOWN_DRIFT',
  // Task 26 ambiguity category.
  'PLAN_AMBIGUITY',
  // Task 26 execution-readiness categories.
  'PLAN_COMMAND_FORBIDDEN_SHELL',
  'PLAN_COMMAND_NODE_OPTION',
  'PLAN_COMMAND_FAILURE_CLASS',
  'PLAN_COMMAND_MARKER_ABSENT',
  'PLAN_COMMAND_INPUT_UNAVAILABLE',
  'PLAN_COMMAND_INPUT_FROM_FUTURE',
  'PLAN_COMMAND_INPUT_AMBIGUOUS',
  'PLAN_COMMAND_INPUT_HASH_MISMATCH',
  'PLAN_FILE_CREATE_COLLISION',
  'PLAN_FILE_MODIFY_UNAVAILABLE',
  'PLAN_FILE_INPUT_UNAVAILABLE_AT_STAGE',
  'PLAN_COMMIT_BOUNDARY_DRIFT',
  'PLAN_RED_SCAFFOLD_MISSING',
  'PLAN_RED_SCAFFOLD_UNREPLACED',
  'PLAN_INTERFACE_SIGNATURE_MISMATCH',
  'PLAN_INTERFACE_ORDER',
  'PLAN_INTERFACE_PRODUCER_DUPLICATE',
  'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
  'PLAN_SOURCE_INPUT_UNDECLARED',
  'PLAN_SOURCE_PRODUCER_ORDER',
  'PLAN_SOURCE_OUTPUT_COLLISION',
  'PLAN_REPOSITORY_MUTATION_UNDECLARED',
  'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT',
  'PLAN_EVIDENCE_JOURNAL_STATE',
  'PLAN_ALL_SUCCESS_ORDER',
  'PLAN_PIPELINE_STATUS',
  'PLAN_RED_SCAFFOLD_MUTATION',
  'PLAN_SCOPE_DELTA',
  'PLAN_PAYLOAD_INDEX',
  'PLAN_CHECKSUM_INDEX',
  'PLAN_ADOPTION_SELECTOR',
  'PLAN_AUTHORITY_NOT_ASSEMBLED',
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
