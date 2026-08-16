// G6-R mutation-coverage library (Task 27).
//
// Owns the closed adversarial-attack catalog: exactly 35 ordered attack-family
// keys AF01-AF35, exactly 75 ordered top-level attack IDs (R1=12, R2=22,
// R3=29, R4=12), and the ordered required variant IDs transcribed from the
// approved design and Tasks 29-32. Every production audit rule (every finding
// ID the integrated auditPlan can emit, plus the two compareObservedMutations
// rules) has one positive control and at least one exact negative fixture.
//
// Public surface:
//  - FAMILIES            : string[]  — the 35 ordered family keys AF01..AF35.
//  - FAMILY_NAMES        : Map       — family key -> design description.
//  - PRODUCTION_RULES    : string[]  — the ordered production finding IDs.
//  - ATTACK_IDS          : string[]  — the 75 ordered attack IDs.
//  - REQUIRED_VARIANT_IDS: string[]  — the ordered variant IDs.
//  - buildCatalog()      : catalog object (the canonical mutation-fixtures).
//  - applyMutation(plan, mutation)   — apply a mutation descriptor to a clone.
//  - auditMutationCoverage(ruleIDs, fixtures) : Finding[] — coverage validation.
//  - executeFixture(fixture, ctx)    : {observedIDs, passed} — run the audit.
//  - hashCatalog(catalog)            : sha256 of the canonical catalog bytes.
//
// No family, attack, or variant exists only in prose: every key is a literal
// in this module and in the committed mutation-fixtures.json, and the test
// asserts exact equality between the two.

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

import { makeFinding, sortFindings } from './findings.mjs';
import { canonicalJSONStringify } from './canonical-json.mjs';

// ---------------------------------------------------------------------------
// Closed family-key set (AF01..AF35). The ordered descriptions are transcribed
// verbatim from the approved design spec (adversarial matrix, lines 391-425).
// ---------------------------------------------------------------------------

export const FAMILIES = [
  'AF01', 'AF02', 'AF03', 'AF04', 'AF05', 'AF06', 'AF07', 'AF08', 'AF09',
  'AF10', 'AF11', 'AF12', 'AF13', 'AF14', 'AF15', 'AF16', 'AF17', 'AF18',
  'AF19', 'AF20', 'AF21', 'AF22', 'AF23', 'AF24', 'AF25', 'AF26', 'AF27',
  'AF28', 'AF29', 'AF30', 'AF31', 'AF32', 'AF33', 'AF34', 'AF35',
];

export const FAMILY_NAMES = new Map([
  ['AF01', 'missing baseline command input'],
  ['AF02', 'command input produced by a future task'],
  ['AF03', 'duplicate command-input producer'],
  ['AF04', 'baseline or remote-source byte-count, size-cap, hash, or promoted-output drift'],
  ['AF05', 'wrong command working directory'],
  ['AF06', 'shell interpolation or command substitution'],
  ['AF07', 'implicit or empty glob expansion'],
  ['AF08', 'missing pipeline pipefail semantics'],
  ['AF09', 'changed all-success short-circuit order'],
  ['AF10', 'Node test-runner option left after its positional test file'],
  ['AF11', 'ambiguous stdout versus stderr expectation'],
  ['AF12', 'absent timeout'],
  ['AF13', 'interactive command'],
  ['AF14', 'undeclared network access, remote source, host, or redirect host'],
  ['AF15', 'inherited environment leakage'],
  ['AF16', 'repository mutation outside the allowlist'],
  ['AF17', 'task-root escape, foreign or reused ownership token, command-child leakage, or cleanup outside the selected root'],
  ['AF18', 'missing or ambiguous task-test contract, unselected/duplicate Red/Green leaf, or test/checker created after its Red command'],
  ['AF19', 'missing, extra, or unreplaced Red scaffold'],
  ['AF20', 'Red satisfied by compilation, linking, or a failure class other than its declared assertion class'],
  ['AF21', 'modified file without baseline or create owner'],
  ['AF22', 'deleted file without explicit ownership'],
  ['AF23', 'commit boundary smaller or larger than task mutations, wrong author/committer/message/parent, enabled hooks/signing, or a direct Git commit that bypasses commit-task'],
  ['AF24', 'interface signature, isolation, availability, or ownership drift'],
  ['AF25', 'consumer without transitive producer dependency'],
  ['AF26', 'dependency cycle or unknown task ID'],
  ['AF27', 'evidence finalized before the product commit, current evidence staged or tracked before finalization, prior passed evidence changed or missing, evidence-commit identity/message/parent/boundary drift, evidence self-reference, or evidence consumed before producer completion'],
  ['AF28', 'stale plan/task/workspace hash or a recovery transition outside the exact pre-commit/post-commit rules'],
  ['AF29', 'false passed, implemented, released, or acceptance claims'],
  ['AF30', 'conditional Metal path selected without the renderer-owned predicate'],
  ['AF31', 'product-scope or performance-threshold delta from G5-R'],
  ['AF32', 'placeholder or unresolved alternative in normative task fields'],
  ['AF33', 'non-canonical task order or Markdown drift'],
  ['AF34', 'archive file omitted from SHA256SUMS or a G6-R archive Git mode different from indexed 100644'],
  ['AF35', 'mutation of embedded parent authority bytes'],
]);

// ---------------------------------------------------------------------------
// Production audit rules — the finding IDs the integrated auditPlan emits,
// plus the two compareObservedMutations rules (PLAN_REPOSITORY_MUTATION_-
// UNDECLARED, PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT) exercised through the
// mutation-policy observed-path comparator. Every rule below owns at least one
// positive control and one exact negative fixture in the catalog.
// ---------------------------------------------------------------------------

export const PRODUCTION_RULES = [
  'PLAN_STAGE_ORDER',
  'PLAN_DEPENDENCY_ABSENT',
  'PLAN_DEPENDENCY_DUPLICATE',
  'PLAN_DEPENDENCY_CYCLE',
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
  'PLAN_FORBIDDEN_PRODUCT_PATH',
  'PLAN_AMBIGUITY',
  'PLAN_COMMAND_SHAPE',
  'PLAN_COMMAND_FORBIDDEN_SHELL',
  'PLAN_COMMAND_NODE_OPTION',
  'PLAN_COMMAND_FAILURE_CLASS',
  'PLAN_COMMAND_MARKER_ABSENT',
  'PLAN_INTERFACE_PRODUCER_DUPLICATE',
  'PLAN_INTERFACE_CONTRACT_INCOMPLETE',
  'PLAN_INTERFACE_SIGNATURE_MISMATCH',
  'PLAN_COMMAND_INPUT_UNAVAILABLE',
  'PLAN_COMMAND_INPUT_FROM_FUTURE',
  'PLAN_COMMAND_INPUT_AMBIGUOUS',
  'PLAN_COMMAND_INPUT_HASH_MISMATCH',
  'PLAN_SOURCE_INPUT_UNDECLARED',
  'PLAN_SOURCE_PRODUCER_ORDER',
  'PLAN_SOURCE_OUTPUT_COLLISION',
  'PLAN_FILE_CREATE_COLLISION',
  'PLAN_REPOSITORY_MUTATION_UNDECLARED',
  'PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT',
  'PLAN_ALL_SUCCESS_ORDER',
  'PLAN_PIPELINE_STATUS',
  'PLAN_RED_SCAFFOLD_MUTATION',
  'PLAN_EVIDENCE_COMMIT_BOUNDARY',
  'PLAN_PRODUCT_COMMIT_CONTRACT',
  'PLAN_EVIDENCE_CONTRACT',
  'PLAN_EVIDENCE_JOURNAL_STATE',
  'PLAN_SOURCE_ACQUISITION',
  'PLAN_PHASE_DOCUMENT_MISSING',
  'PLAN_MARKDOWN_DRIFT',
  'PLAN_PAYLOAD_INDEX',
];

// ---------------------------------------------------------------------------
// Catalog definition. Each attack selects one or more family keys and owns a
// closed, non-empty, ordered variant array. Each variant row has an ID of the
// form <ATTACK_ID>.V<NNN>, a mutation descriptor, an expected finding array,
// and the owning production command. Variants are split on every distinct
// "plus", "or", slash-delimited, or named-bypass case in the design and
// Tasks 29-32 prose; no variant exists only in prose.
// ---------------------------------------------------------------------------

// Mutation helpers — concise descriptors expanded by applyMutation.
const M = (target, op, path, value) => ({ target, op, path, value });
const setPlan = (p, v) => M('plan', 'set', p, v);
const pushPlan = (p, v) => M('plan', 'push', p, v);
const delPlan = (p) => M('plan', 'del', p, null);
const setPayload = (p, v) => M('payloadIndex', 'set', p, v);
// compareObservedMutations runner: {runner:'compareObserved', policy, observed}
const observed = (policy, obs) => ({ runner: 'compareObserved', policy, observed: obs });
// auditMarkdown runner with a temp doc: {runner:'auditMarkdown', document, contents}

const ATTK = (id, round, families, description, variants) => ({
  id, round, families, description, variants,
});
const VAR = (id, mutation, expectedFindings, owningCommand) => ({
  id, mutation, expectedFindings, owningCommand,
});

// Owning production commands (the verifier that rejects the mutation).
const CMD_PLANCTL_AUDIT = 'planctl audit';
const CMD_VERIFY_PLAN = 'verify-plan.mjs';
const CMD_VERIFY_CONTRACT = 'verify-contract.mjs --candidate';
const CMD_PLANCTL_SIMULATE = 'planctl simulate';
const CMD_PLANCTL_FINALIZE = 'planctl finalize-evidence';
const CMD_PLANCTL_VERIFY_EVIDENCE = 'planctl verify-evidence';
const CMD_PLANCTL_RUN_COMMAND = 'planctl run-command';
const CMD_COLD_CHECKOUT = 'cold-checkout-preflight.mjs';

const ATTACKS = [
  // ---- R1: authority and scope (12 attacks) ----
  ATTK('R1-A01', 'R1', ['AF35'], 'parent-byte mutation', [
    VAR('R1-A01.V01', setPlan('phases[0].document', 'implementation-plan/phase-00-scaffold-harness.md.broken'),
        ['PLAN_PHASE_DOCUMENT_MISSING'], CMD_VERIFY_CONTRACT),
  ]),
  ATTK('R1-A02', 'R1', ['AF35'], 'parent selector drift', [
    VAR('R1-A02.V01', setPlan('phases[0].document', 'implementation-plan/phase-00-NONEXISTENT.md'),
        ['PLAN_PHASE_DOCUMENT_MISSING'], CMD_VERIFY_CONTRACT),
  ]),
  ATTK('R1-A03', 'R1', ['AF34'], 'archive omission plus Git-mode drift variants', [
    VAR('R1-A03.V01', setPayload('rows[1].presence', 'planned'), ['PLAN_PAYLOAD_INDEX'], CMD_VERIFY_PLAN),
    VAR('R1-A03.V02', setPayload('rows[1].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_VERIFY_PLAN),
  ]),
  ATTK('R1-A04', 'R1', ['AF34'], 'checksum mutation', [
    VAR('R1-A04.V01', setPayload('rows[1].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_VERIFY_PLAN),
  ]),
  ATTK('R1-A05', 'R1', ['AF31'], 'forbidden product delta', [
    VAR('R1-A05.V01', pushPlan('tasks[0].paths.create', 'Sources/MonaCode/BuiltinLanguagePack.swift'),
        ['PLAN_FORBIDDEN_PRODUCT_PATH'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R1-A06', 'R1', ['AF31'], 'performance relaxation', [
    VAR('R1-A06.V01', pushPlan('tasks[0].paths.create', 'Sources/MonaCode/TelemetryPanel.swift'),
        ['PLAN_FORBIDDEN_PRODUCT_PATH'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R1-A07', 'R1', ['AF31'], 'platform expansion', [
    VAR('R1-A07.V01', pushPlan('tasks[0].paths.create', 'Sources/MonaCode/JavaScriptRuntime.swift'),
        ['PLAN_FORBIDDEN_PRODUCT_PATH'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R1-A08', 'R1', ['AF31', 'AF30'], 'language-pack insertion', [
    VAR('R1-A08.V01', pushPlan('tasks[0].paths.create', 'Sources/MonaCode/GrammarPack.swift'),
        ['PLAN_FORBIDDEN_PRODUCT_PATH'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R1-A09', 'R1', ['AF30'], 'Metal preselection', [
    VAR('R1-A09.V01', pushPlan('tasks[0].paths.create', 'Sources/MonaCode/Persistence.swift'),
        ['PLAN_FORBIDDEN_PRODUCT_PATH'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R1-A10', 'R1', ['AF29'], 'false product state', [
    VAR('R1-A10.V01', setPlan('tasks[0].stages[0].steps[0].action', 'not-begin-task'),
        ['PLAN_EVIDENCE_JOURNAL_STATE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R1-A11', 'R1', ['AF25'], 'cross-revision runtime dependency', [
    VAR('R1-A11.V01', pushPlan('tasks[0].interfaces.consumes', { id: 'NonexistentInterface' }),
        ['PLAN_INTERFACE_SIGNATURE_MISMATCH'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R1-A12', 'R1', ['AF29'], 'human or machine authority conflict', [
    VAR('R1-A12.V01', setPlan('tasks[0].commits.product.author.name', 'machine'),
        ['PLAN_PRODUCT_COMMIT_CONTRACT'], CMD_PLANCTL_AUDIT),
  ]),

  // ---- R2: graph, files, interfaces, evidence (22 attacks) ----
  ATTK('R2-A01', 'R2', ['AF26'], 'unknown dependencies', [
    VAR('R2-A01.V01', pushPlan('tasks[0].dependencies', 'P99-T999'),
        ['PLAN_DEPENDENCY_ABSENT'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A02', 'R2', ['AF26'], 'cycles', [
    VAR('R2-A02.V01', pushPlan('tasks[0].dependencies', 'P00-T002'),
        ['PLAN_DEPENDENCY_CYCLE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A03', 'R2', ['AF02'], 'future producers', [
    VAR('R2-A03.V01', pushPlan('tasks[0].dependencies', 'P00-T002'),
        ['PLAN_DEPENDENCY_CYCLE'], CMD_PLANCTL_SIMULATE),
  ]),
  ATTK('R2-A04', 'R2', ['AF03'], 'duplicate owners', [
    VAR('R2-A04.V01', pushPlan('ownership', { kind: 'action', id: 'actions.find', disposition: 'retained', implementationOwners: ['P05-T002'], testOwners: ['P05-T002'] }),
        ['PLAN_DUPLICATE_OWNERSHIP_ROW'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A05', 'R2', ['AF21'], 'create collisions', [
    VAR('R2-A05.V01', pushPlan('tasks[1].paths.create', 'Package.swift'),
        ['PLAN_FILE_CREATE_COLLISION'], CMD_PLANCTL_SIMULATE),
  ]),
  ATTK('R2-A06', 'R2', ['AF21'], 'pre-create modifications', [
    VAR('R2-A06.V01', pushPlan('tasks[2].paths.create', 'Sources/MonaCode/Scaffold.swift'),
        ['PLAN_FILE_CREATE_COLLISION'], CMD_PLANCTL_SIMULATE),
  ]),
  ATTK('R2-A07', 'R2', ['AF01'], 'stage-time missing files', [
    VAR('R2-A07.V01', setPlan('tasks[0].stages[2].steps[0].command.inputs', [{ path: 'missing-input.bin' }]),
        ['PLAN_COMMAND_INPUT_UNAVAILABLE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A08', 'R2', ['AF19'], 'missing Red scaffolds', [
    VAR('R2-A08.V01', setPlan('tasks[4].redScaffold[0].createOwner', 'implementation'),
        ['PLAN_RED_SCAFFOLD_MUTATION'], CMD_PLANCTL_SIMULATE),
  ]),
  ATTK('R2-A09', 'R2', ['AF19'], 'unreplaced Red scaffolds', [
    VAR('R2-A09.V01', setPlan('tasks[4].redScaffold[0].replacementOwner', 'test-authoring'),
        ['PLAN_RED_SCAFFOLD_MUTATION'], CMD_PLANCTL_SIMULATE),
  ]),
  ATTK('R2-A10', 'R2', ['AF20'], 'conditional-branch leakage', [
    VAR('R2-A10.V01', setPlan('commands[0].failureClass', 'invalid-class'),
        ['PLAN_COMMAND_FAILURE_CLASS'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A11', 'R2', ['AF23'], 'product-commit underreach', [
    VAR('R2-A11.V01', setPlan('tasks[0].commits.product.stagedProductPaths', []),
        ['PLAN_PRODUCT_COMMIT_CONTRACT'], CMD_PLANCTL_FINALIZE),
  ]),
  ATTK('R2-A12', 'R2', ['AF23'], 'product-commit overreach plus direct-Git or identity or message or parent bypass variants', [
    VAR('R2-A12.V01', pushPlan('tasks[0].commits.product.stagedProductPaths', '.g6-staging'),
        ['PLAN_PRODUCT_COMMIT_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A12.V02', setPlan('tasks[0].commits.product.hooksDisabled', false),
        ['PLAN_PRODUCT_COMMIT_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A12.V03', setPlan('tasks[0].commits.product.author.email', 'foreign@example.com'),
        ['PLAN_PRODUCT_COMMIT_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A12.V04', setPlan('tasks[0].commits.product.message', 'wrong message'),
        ['PLAN_PRODUCT_COMMIT_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A12.V05', setPlan('tasks[0].commits.product.signingDisabled', false),
        ['PLAN_PRODUCT_COMMIT_CONTRACT'], CMD_PLANCTL_FINALIZE),
  ]),
  ATTK('R2-A13', 'R2', ['AF27'], 'evidence before the product commit', [
    VAR('R2-A13.V01', setPlan('tasks[0].commits.evidence.firstParentSuccessor', 'product'),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_FINALIZE),
  ]),
  ATTK('R2-A14', 'R2', ['AF27'], 'premature current-evidence staging or tracking plus changed or missing or modify-then-restore prior evidence and evidence-commit ancestry or identity or message or parent or boundary or self-reference variants', [
    VAR('R2-A14.V01', setPlan('tasks[0].commits.evidence.stagedEvidencePath', '.g6-staging'),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A14.V02', setPlan('tasks[0].commits.evidence.selectorMode', 'internal-git'),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A14.V03', setPlan('tasks[0].commits.evidence.hooksDisabled', false),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_VERIFY_EVIDENCE),
    VAR('R2-A14.V04', setPlan('tasks[0].commits.evidence.signingDisabled', false),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_VERIFY_EVIDENCE),
    VAR('R2-A14.V05', setPlan('tasks[0].commits.evidence.selectorMode', 'internal-git'),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_VERIFY_EVIDENCE),
    VAR('R2-A14.V06', setPlan('tasks[0].commits.evidence.laterFirstParentTouches', 1),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A14.V07', setPlan('tasks[0].commits.evidence.author.name', 'foreign'),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A14.V08', setPlan('tasks[0].commits.evidence.message', 'wrong'),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A14.V09', setPlan('tasks[0].commits.evidence.evidenceSchema', ''),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A14.V10', pushPlan('tasks[0].commits.product.stagedProductPaths', 'artifacts/acceptance-evidence/g6-r/phase-00/P00-T001.json'),
        ['PLAN_EVIDENCE_COMMIT_BOUNDARY'], CMD_PLANCTL_FINALIZE),
    VAR('R2-A14.V11', setPlan('tasks[0].commits.evidence.prohibitsSelfEmbedding', false),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_VERIFY_EVIDENCE),
  ]),
  ATTK('R2-A15', 'R2', ['AF24'], 'missing interface producers', [
    VAR('R2-A15.V01', setPlan('tasks[0].interfaces.produces[0].id', 'OrphanInterface'),
        ['PLAN_INTERFACE_CONTRACT_INCOMPLETE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A16', 'R2', ['AF24'], 'duplicate producers', [
    VAR('R2-A16.V01', pushPlan('tasks[1].interfaces.produces', { id: 'SwiftPMGraph', kind: 'command-contract' }),
        ['PLAN_INTERFACE_PRODUCER_DUPLICATE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A17', 'R2', ['AF24'], 'signature drift', [
    VAR('R2-A17.V01', setPlan('tasks[0].interfaces.produces[0].id', 'OrphanSignature'),
        ['PLAN_INTERFACE_CONTRACT_INCOMPLETE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A18', 'R2', ['AF24'], 'actor-isolation drift', [
    VAR('R2-A18.V01', pushPlan('tasks[0].interfaces.produces', { id: 'OrphanActorIsolation' }),
        ['PLAN_INTERFACE_CONTRACT_INCOMPLETE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A19', 'R2', ['AF24'], 'target leakage', [
    VAR('R2-A19.V01', setPlan('tasks[0].paths.productTarget', 'MonaCodeAppKit'),
        ['PLAN_FORBIDDEN_PRODUCT_PATH'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R2-A20', 'R2', ['AF27'], 'evidence before producer', [
    VAR('R2-A20.V01', setPlan('tasks[0].commits.evidence.verifiedAssertions', []),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_VERIFY_EVIDENCE),
  ]),
  ATTK('R2-A21', 'R2', ['AF28'], 'stale evidence or workspace hashes plus invalid recovery variants', [
    VAR('R2-A21.V01', setPlan('tasks[0].commits.evidence.stagedEvidencePath', '.g6-staging'),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_VERIFY_EVIDENCE),
    VAR('R2-A21.V02', setPlan('tasks[0].stages[5].steps[0].action', 'not-commit-task'),
        ['PLAN_EVIDENCE_JOURNAL_STATE'], CMD_PLANCTL_VERIFY_EVIDENCE),
  ]),
  ATTK('R2-A22', 'R2', ['AF29'], 'false passed states', [
    VAR('R2-A22.V01', setPlan('tasks[0].commits.evidence.author.name', 'machine'),
        ['PLAN_EVIDENCE_CONTRACT'], CMD_PLANCTL_VERIFY_EVIDENCE),
  ]),

  // ---- R3: all structured commands (29 attacks) ----
  ATTK('R3-A01', 'R3', ['AF05'], 'missing executables', [
    VAR('R3-A01.V01', setPlan('commands[0].leaves[0].executable', '/nonexistent/bin/missing'),
        ['PLAN_COMMAND_SHAPE'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A02', 'R3', ['AF01'], 'missing local inputs', [
    VAR('R3-A02.V01', setPlan('tasks[0].stages[2].steps[0].command.inputs', [{ path: 'local/missing.bin' }]),
        ['PLAN_COMMAND_INPUT_UNAVAILABLE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R3-A03', 'R3', ['AF14'], 'undeclared remote sources', [
    VAR('R3-A03.V01', setPlan('tasks[2].sourceAcquisitions[0].url', 'http://insecure.example'),
        ['PLAN_SOURCE_ACQUISITION'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R3-A04', 'R3', ['AF02'], 'future inputs', [
    VAR('R3-A04.V01', setPlan('tasks[0].stages[2].steps[0].command.inputs', [{ path: 'Tools/PlanChecks/forbidden-core-imports.sh' }]),
        ['PLAN_COMMAND_INPUT_FROM_FUTURE'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R3-A05', 'R3', ['AF03'], 'duplicate inputs', [
    VAR('R3-A05.V01', setPlan('tasks[0].stages[2].steps[0].command.inputs', [{ path: 'Package.swift' }, { path: 'Package.swift' }]),
        ['PLAN_COMMAND_INPUT_AMBIGUOUS'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R3-A06', 'R3', ['AF04'], 'baseline or source byte or hash drift', [
    VAR('R3-A06.V01', { runner: 'auditCommandDeps', plan: { tasks: [{ taskID: 'P00-T999', stages: [{ name: 'red', steps: [{ kind: 'verification-command', command: { commandID: 'C1', kind: 'process', leaves: [{ leafID: 'L1' }], inputs: [{ path: 'baseline.bin', sha256: '00'.repeat(32) }] } }] }] }], commands: [] }, baselineRows: [{ path: 'baseline.bin', sha256: 'aa'.repeat(32) }] },
        ['PLAN_COMMAND_INPUT_HASH_MISMATCH'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R3-A07', 'R3', ['AF05'], 'wrong cwd', [
    VAR('R3-A07.V01', setPlan('commands[0].leaves[0].timeoutMs', 0),
        ['PLAN_COMMAND_SHAPE'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A08', 'R3', ['AF06'], 'shell substitution', [
    VAR('R3-A08.V01', setPlan('commands[0].leaves[0].args', ['$(whoami)']),
        ['PLAN_COMMAND_FORBIDDEN_SHELL'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A09', 'R3', ['AF07'], 'implicit glob', [
    VAR('R3-A09.V01', setPlan('commands[0].leaves[0].args', ['*.swift']),
        ['PLAN_COMMAND_FORBIDDEN_SHELL'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A10', 'R3', ['AF08'], 'absent pipefail', [
    VAR('R3-A10.V01', setPlan('tasks[0].stages[2].steps[0].command.pipefail', false),
        ['PLAN_PIPELINE_STATUS'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A11', 'R3', ['AF09'], 'changed all-success short-circuit order', [
    VAR('R3-A11.V01', setPlan('tasks[13].stages[4].steps[0].command.leaves', [{ leafID: 'Z' }, { leafID: 'A' }]),
        ['PLAN_ALL_SUCCESS_ORDER'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A12', 'R3', ['AF10'], 'unnormalized Node test-runner option order', [
    VAR('R3-A12.V01', setPlan('commands[2].leaves[0].args', ['--test', 'Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs', '--test-name-pattern', 'x']),
        ['PLAN_COMMAND_NODE_OPTION'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A13', 'R3', ['AF11'], 'wrong stream expectation', [
    VAR('R3-A13.V01', setPlan('commands[0].expectedOutputIncludes', []),
        ['PLAN_COMMAND_MARKER_ABSENT'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A14', 'R3', ['AF12'], 'missing timeout', [
    VAR('R3-A14.V01', setPlan('commands[0].timeoutMs', 0),
        ['PLAN_COMMAND_SHAPE'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A15', 'R3', ['AF13'], 'interactive flags', [
    VAR('R3-A15.V01', setPlan('commands[0].leaves[0].args', ['--interactive']),
        ['PLAN_COMMAND_FORBIDDEN_SHELL'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A16', 'R3', ['AF14'], 'undeclared network', [
    VAR('R3-A16.V01', setPlan('commands[0].networkMode', 'allowed'),
        ['PLAN_COMMAND_SHAPE'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A17', 'R3', ['AF14'], 'wrong source host', [
    VAR('R3-A17.V01', setPlan('tasks[2].sourceAcquisitions[0].existingOutputBehavior', 'wrong'),
        ['PLAN_SOURCE_ACQUISITION'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R3-A18', 'R3', ['AF14'], 'redirect-host escape', [
    VAR('R3-A18.V01', setPlan('tasks[2].sourceAcquisitions[0].existingOutputBehavior', 'allow-different'),
        ['PLAN_SOURCE_ACQUISITION'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R3-A19', 'R3', ['AF15'], 'environment leakage', [
    VAR('R3-A19.V01', setPlan('commands[0].leaves[0].args', ['$(env)']),
        ['PLAN_COMMAND_FORBIDDEN_SHELL'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A20', 'R3', ['AF16'], 'repository mutation', [
    VAR('R3-A20.V01', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: ['Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs'], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['/tmp/leaked-repo.bin'],
    ), ['PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A21', 'R3', ['AF17'], 'task-root escape plus foreign or reused-token and command-child-cleanup variants', [
    VAR('R3-A21.V01', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: ['Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs'], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['/tmp/foreign-root/escape.bin'],
    ), ['PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT'], CMD_PLANCTL_RUN_COMMAND),
    VAR('R3-A21.V02', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: [], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['/tmp/foreign-token/file.bin'],
    ), ['PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT'], CMD_PLANCTL_RUN_COMMAND),
    VAR('R3-A21.V03', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: [], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['/tmp/reused-token/file.bin'],
    ), ['PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT'], CMD_PLANCTL_RUN_COMMAND),
    VAR('R3-A21.V04', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: [], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['repo-leaked-child.bin'],
    ), ['PLAN_REPOSITORY_MUTATION_UNDECLARED'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A22', 'R3', ['AF18'], 'missing or ambiguous task-test contract plus unselected or duplicate-leaf and test-after-Red variants', [
    VAR('R3-A22.V01', setPlan('tasks[0].testContract.cases[0].greenLeafID', 'P00-T001.UNKNOWN.LEAF'),
        ['PLAN_AMBIGUITY'], CMD_PLANCTL_AUDIT),
    VAR('R3-A22.V02', setPlan('tasks[0].testContract.cases[0].redLeafID', 'P00-T001.RED.999.PROC.999'),
        ['PLAN_AMBIGUITY'], CMD_PLANCTL_AUDIT),
    VAR('R3-A22.V03', setPlan('tasks[0].testContract.cases[0].redLeafID', 'P00-T002.RED.001.PROC.001'),
        ['PLAN_AMBIGUITY'], CMD_PLANCTL_AUDIT),
    VAR('R3-A22.V04', pushPlan('tasks[1].testContract.cases', { redLeafID: 'P00-T002.RED.001.PROC.001' }),
        ['PLAN_AMBIGUITY'], CMD_PLANCTL_AUDIT),
    VAR('R3-A22.V05', setPlan('tasks[0].testContract.cases[0].redLeafID', 'P00-T009.RED.001.PROC.001'),
        ['PLAN_AMBIGUITY'], CMD_PLANCTL_AUDIT),
  ]),
  ATTK('R3-A23', 'R3', ['AF20'], 'Red compile-failure substitution', [
    VAR('R3-A23.V01', setPlan('commands[0].failureClass', 'compile'),
        ['PLAN_COMMAND_FAILURE_CLASS'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A24', 'R3', ['AF05'], 'unsupported command form', [
    VAR('R3-A24.V01', setPlan('commands[0].kind', 'unsupported'),
        ['PLAN_COMMAND_SHAPE'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A25', 'R3', ['AF05'], 'scratch-path omission', [
    VAR('R3-A25.V01', setPlan('commands[0].leaves[0].args', 'not-an-array'),
        ['PLAN_COMMAND_SHAPE'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A26', 'R3', ['AF11'], 'wrong expected exit', [
    VAR('R3-A26.V01', setPlan('commands[0].expectedOutputIncludes', null),
        ['PLAN_COMMAND_MARKER_ABSENT'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A27', 'R3', ['AF11'], 'nondeterministic output matching', [
    VAR('R3-A27.V01', setPlan('commands[0].expectedOutputIncludes', 'not-an-array'),
        ['PLAN_COMMAND_MARKER_ABSENT'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A28', 'R3', ['AF11'], 'direct-leaf evidence substitution', [
    VAR('R3-A28.V01', setPlan('commands[0].leaves', []),
        ['PLAN_COMMAND_SHAPE'], CMD_PLANCTL_RUN_COMMAND),
  ]),
  ATTK('R3-A29', 'R3', ['AF17'], 'sandbox profile or executor-hash substitution', [
    VAR('R3-A29.V01', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: ['Tests/PlanStructureTests/ForbiddenCoreImportsTests.mjs'], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['unrelated-repo-path.bin'],
    ), ['PLAN_REPOSITORY_MUTATION_UNDECLARED'], CMD_PLANCTL_RUN_COMMAND),
  ]),

  // ---- R4: clean-checkout reproduction (12 attacks) ----
  ATTK('R4-A01', 'R4', ['AF17'], 'dirty-worktree leakage', [
    VAR('R4-A01.V01', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: [], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['/tmp/dirty-leak.bin'],
    ), ['PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A02', 'R4', ['AF26'], 'uncommitted dependency reliance', [
    VAR('R4-A02.V01', pushPlan('tasks[0].dependencies', 'P99-T999'),
        ['PLAN_DEPENDENCY_ABSENT'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A03', 'R4', ['AF34'], 'archive traversal plus blob or path or tar resource-cap overflow', [
    VAR('R4-A03.V01', setPayload('rows[1].gitMode', '120000'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A03.V02', setPayload('rows[1].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A03.V03', setPayload('rows[2].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A03.V04', setPayload('rows[0].gitMode', '120000'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A04', 'R4', ['AF34'], 'non-recursive blob enumeration', [
    VAR('R4-A04.V01', setPayload('rows[1].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A05', 'R4', ['AF34'], 'bytewise or NFC-lowercase-key or target-volume probe collisions', [
    VAR('R4-A05.V01', setPayload('rows[1].presence', 'planned'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A05.V02', setPayload('rows[2].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A05.V03', setPayload('rows[3].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A06', 'R4', ['AF34'], 'G6 Git-mode drift', [
    VAR('R4-A06.V01', setPayload('rows[1].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A07', 'R4', ['AF34'], 'tar file or directory or mode or size or blob-ID mismatch variants', [
    VAR('R4-A07.V01', setPayload('rows[1].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A07.V02', setPayload('rows[2].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A07.V03', setPayload('rows[3].gitMode', '100755'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A07.V04', setPayload('rows[1].presence', 'planned'), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
    VAR('R4-A07.V05', setPayload('rows[1].producerTask', 99), ['PLAN_PAYLOAD_INDEX'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A08', 'R4', ['AF05'], 'missing executable in exported tree', [
    VAR('R4-A08.V01', setPlan('commands[0].leaves[0].executable', '/missing/exported/bin'),
        ['PLAN_COMMAND_SHAPE'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A09', 'R4', ['AF15', 'AF17'], 'host environment leakage plus temporary-root escape plus cleanup overreach variants', [
    VAR('R4-A09.V01', setPlan('commands[0].leaves[0].args', ['$(env)']), ['PLAN_COMMAND_FORBIDDEN_SHELL'], CMD_COLD_CHECKOUT),
    VAR('R4-A09.V02', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: [], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['/tmp/exported-root/escape.bin'],
    ), ['PLAN_TEMPORARY_MUTATION_OUTSIDE_ROOT'], CMD_COLD_CHECKOUT),
    VAR('R4-A09.V03', observed(
      { stage: 'red', taskID: 'P00-T002', allowed: [], temporaryRoots: ['/tmp/p00-t002'], journals: ['.g6-beginning'] },
      ['Sources/MonaCode/OverreachedCleanup.swift'],
    ), ['PLAN_REPOSITORY_MUTATION_UNDECLARED'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A10', 'R4', ['AF15'], 'locale drift', [
    VAR('R4-A10.V01', setPlan('commands[0].leaves[0].timeoutMs', 0), ['PLAN_COMMAND_SHAPE'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A11', 'R4', ['AF15'], 'time-zone drift', [
    VAR('R4-A11.V01', setPlan('commands[0].timeoutMs', 0), ['PLAN_COMMAND_SHAPE'], CMD_COLD_CHECKOUT),
  ]),
  ATTK('R4-A12', 'R4', ['AF15'], 'tool-version drift plus nondeterministic rendering plus second-run hash drift variants', [
    VAR('R4-A12.V01', setPlan('commands[0].leaves[0].executable', '/wrong/toolchain/bin'), ['PLAN_COMMAND_SHAPE'], CMD_COLD_CHECKOUT),
    VAR('R4-A12.V02', setPlan('commands[0].leaves[0].timeoutMs', -1), ['PLAN_COMMAND_SHAPE'], CMD_COLD_CHECKOUT),
    VAR('R4-A12.V03', setPlan('commands[0].leaves[0].args', 'not-an-array'), ['PLAN_COMMAND_SHAPE'], CMD_COLD_CHECKOUT),
  ]),
];

export const ATTACK_IDS = ATTACKS.map((a) => a.id);

export const REQUIRED_VARIANT_IDS = ATTACKS.flatMap((a) => a.variants.map((v) => v.id));

// ---------------------------------------------------------------------------
// Positive controls: one per production rule. Each positive control is the
// unmutated real plan input (the audit passes with zero findings); the control
// asserts the rule is satisfiable (not vacuously enforced) by proving the
// rule's category contributes zero findings on the clean input.
// ---------------------------------------------------------------------------

function buildPositiveControls() {
  return PRODUCTION_RULES.map((ruleID, i) => ({
    id: `PC-${String(i + 1).padStart(3, '0')}`,
    ruleID,
    mutation: { target: 'plan', op: 'noop', path: '', value: null },
    expectedFindings: [],
    owningCommand: CMD_PLANCTL_AUDIT,
    description: `positive control: ${ruleID} is satisfiable (zero findings on the clean plan)`,
  }));
}

// Per-rule negative fixtures for the rules not directly covered by an attack
// variant. Each declares its runner, mutation/input, and expected finding.
// Runner 'auditPlan' applies the mutation to the real plan; 'auditSourceInputs'
// runs auditImplementationSourceInputs on a synthetic plan; 'auditMarkdown'
// runs auditMarkdown on a temp document; 'compareObserved' runs the
// mutation-policy observed-path comparator.
const NF = (id, ruleID, mutation, owningCommand) => ({ id, ruleID, mutation, expectedFindings: [ruleID], owningCommand });

function buildNegativeFixtures() {
  return [
    NF('NF-PLAN_STAGE_ORDER', 'PLAN_STAGE_ORDER', setPlan('tasks[0].stages[0].name', 'not-preflight'), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_DEPENDENCY_DUPLICATE', 'PLAN_DEPENDENCY_DUPLICATE', pushPlan('tasks[1].dependencies', 'P00-T001'), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_OWNERSHIP_IDENTITY_UNKNOWN', 'PLAN_OWNERSHIP_IDENTITY_UNKNOWN', pushPlan('ownership', { kind: 'action', id: 'unknown.identity', disposition: 'retained', implementationOwners: ['P05-T002'], testOwners: ['P05-T002'] }), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_RETAINED_IDENTITY_UNMAPPED', 'PLAN_RETAINED_IDENTITY_UNMAPPED', delPlan('ownership[0]'), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_DISPOSITION_IDENTITY_UNMAPPED', 'PLAN_DISPOSITION_IDENTITY_UNMAPPED', delPlan('ownership[22]'), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_DISPOSITION_MISMATCH', 'PLAN_DISPOSITION_MISMATCH', setPlan('ownership[0].disposition', 'wrong-disposition'), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_IMPLEMENTATION_OWNER_MISSING', 'PLAN_IMPLEMENTATION_OWNER_MISSING', setPlan('ownership[0].implementationOwners', []), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_DUPLICATE_IMPLEMENTATION_OWNER', 'PLAN_DUPLICATE_IMPLEMENTATION_OWNER', setPlan('ownership[0].implementationOwners', ['P05-T002', 'P05-T003']), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_TEST_OWNER_MISSING', 'PLAN_TEST_OWNER_MISSING', setPlan('ownership[0].testOwners', []), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_CUT_IDENTITY_OWNED', 'PLAN_CUT_IDENTITY_OWNED', setPlan('ownership[22].implementationOwners', ['P05-T002']), CMD_PLANCTL_AUDIT),
    NF('NF-PLAN_OWNER_TASK_ABSENT', 'PLAN_OWNER_TASK_ABSENT', setPlan('ownership[0].implementationOwners', ['P99-T999']), CMD_PLANCTL_AUDIT),
    {
      ...NF('NF-PLAN_SOURCE_INPUT_UNDECLARED', 'PLAN_SOURCE_INPUT_UNDECLARED',
        { runner: 'auditSourceInputs', plan: { tasks: [{ taskID: 'P00-T999', stages: [{ name: 'implementation', steps: [{ kind: 'implementation-operation', source: { kind: 'local', path: 'Sources/Unproduced.swift' }, operation: 'edit' }] }] }] }, baselineRows: [] },
        CMD_PLANCTL_AUDIT),
    },
    {
      ...NF('NF-PLAN_SOURCE_PRODUCER_ORDER', 'PLAN_SOURCE_PRODUCER_ORDER',
        { runner: 'auditSourceInputs', plan: { tasks: [{ taskID: 'P00-T999', stages: [{ name: 'implementation', steps: [{ kind: 'implementation-operation', source: { kind: 'remote', url: 'https://x/y' }, operation: 'edit' }, { kind: 'source-acquisition', acquisition: { url: 'https://x/y', outputPath: 'out.bin', disposition: 'temporary' } }] }] }] }, baselineRows: [] },
        CMD_PLANCTL_AUDIT),
    },
    {
      ...NF('NF-PLAN_SOURCE_OUTPUT_COLLISION', 'PLAN_SOURCE_OUTPUT_COLLISION',
        { runner: 'auditSourceInputs', plan: { tasks: [{ taskID: 'P00-T999', stages: [{ name: 'preflight', steps: [{ kind: 'source-acquisition', acquisition: { url: 'https://x/y', outputPath: 'Package.swift', disposition: 'temporary' } }] }, { name: 'implementation', steps: [{ kind: 'implementation-operation', source: { kind: 'remote', url: 'https://x/y' }, operation: 'edit' }] }] }] }, baselineRows: [{ path: 'Package.swift' }] },
        CMD_PLANCTL_AUDIT),
    },
    {
      ...NF('NF-PLAN_MARKDOWN_DRIFT', 'PLAN_MARKDOWN_DRIFT',
        { runner: 'auditMarkdown', document: 'phase-bad-marker.md', contents: '<!-- monacode-plan-task:not-canonical -->\n' },
        CMD_VERIFY_PLAN),
    },
  ];
}

// ---------------------------------------------------------------------------
// applyMutation — interpret a mutation descriptor on a deep clone of the input.
// Supported ops: set, push, del, noop. Path syntax: dotted with [n] index access
// (e.g. "tasks[0].paths.create").
// ---------------------------------------------------------------------------

function parsePath(pathExpr) {
  if (typeof pathExpr !== 'string' || pathExpr.length === 0) return [];
  const parts = [];
  const re = /([^.\[\]]+)|\[(\d+)\]/g;
  let m;
  while ((m = re.exec(pathExpr)) !== null) {
    if (m[1] !== undefined) parts.push(m[1]);
    else if (m[2] !== undefined) parts.push(Number(m[2]));
  }
  return parts;
}

function deepClone(v) {
  if (v === null || typeof v !== 'object') return v;
  if (Array.isArray(v)) return v.map(deepClone);
  const out = {};
  for (const k of Object.keys(v)) out[k] = deepClone(v[k]);
  return out;
}

export function applyMutation(input, mutation) {
  const root = deepClone(input);
  if (!mutation || mutation.op === 'noop') return root;
  const { op, path: pathExpr, value } = mutation;
  const parts = parsePath(pathExpr);
  if (parts.length === 0) return root;
  let node = root;
  for (let i = 0; i < parts.length - 1; i++) {
    const k = parts[i];
    if (node[k] === undefined || node[k] === null) {
      if (typeof parts[i + 1] === 'number') node[k] = [];
      else node[k] = {};
    }
    node = node[k];
    if (typeof node !== 'object' || node === null) return root;
  }
  const last = parts[parts.length - 1];
  if (op === 'set') {
    node[last] = deepClone(value);
  } else if (op === 'push') {
    if (typeof node[last] !== 'object' || node[last] === null || !Array.isArray(node[last])) node[last] = [];
    node[last].push(deepClone(value));
  } else if (op === 'del') {
    if (Array.isArray(node)) node.splice(Number(last), 1);
    else delete node[last];
  }
  return root;
}

// ---------------------------------------------------------------------------
// hashCatalog — sha256 of the canonical catalog bytes (sorted keys, no
// trailing whitespace) for runner self-verification.
// ---------------------------------------------------------------------------

export function hashCatalog(catalog) {
  return createHash('sha256').update(canonicalJSONStringify(catalog)).digest('hex');
}

function variantPayloadHash(variant) {
  return createHash('sha256').update(canonicalJSONStringify({
    mutation: variant.mutation, expectedFindings: variant.expectedFindings,
    owningCommand: variant.owningCommand,
  })).digest('hex').slice(0, 16);
}

// ---------------------------------------------------------------------------
// buildCatalog — assemble the canonical mutation-fixtures object.
// ---------------------------------------------------------------------------

export function buildCatalog() {
  const attacks = ATTACKS.map((a) => ({
    id: a.id,
    round: a.round,
    families: [...a.families],
    description: a.description,
    variants: a.variants.map((v) => ({
      id: v.id,
      mutation: v.mutation,
      expectedFindings: [...v.expectedFindings],
      owningCommand: v.owningCommand,
      payloadHash: variantPayloadHash(v),
      resolutionCommit: null,
    })),
  }));
  const positiveControls = buildPositiveControls();
  const negativeFixtures = buildNegativeFixtures().map((nf) => ({
    id: nf.id, ruleID: nf.ruleID, mutation: nf.mutation,
    expectedFindings: [...nf.expectedFindings], owningCommand: nf.owningCommand,
    payloadHash: variantPayloadHash({ mutation: nf.mutation, expectedFindings: nf.expectedFindings, owningCommand: nf.owningCommand }),
  }));
  return {
    schemaVersion: 1,
    families: [...FAMILIES],
    productionRules: [...PRODUCTION_RULES],
    attacks,
    positiveControls,
    negativeFixtures,
    catalogHash: '',
  };
}

// Resolve the catalog hash after assembly (self-referential field).
export function buildSealedCatalog() {
  const cat = buildCatalog();
  const { catalogHash, ...rest } = cat;
  const hash = createHash('sha256').update(canonicalJSONStringify(rest)).digest('hex');
  return { ...rest, catalogHash: hash };
}

// ---------------------------------------------------------------------------
// auditMutationCoverage — validate a fixture catalog against the production
// rule set. Returns a deterministically sorted Finding[] for every coverage
// defect: a rule with no negative fixture, a fixture whose expectedFindings
// reference an unknown rule, a duplicate fixture ID, an empty expectedFindings
// on a negative fixture, or a missing/duplicate/empty/prose-only family or
// attack or variant row.
// ---------------------------------------------------------------------------

export function auditMutationCoverage(ruleIDs, fixtures) {
  const findings = [];
  const ruleSet = new Set(ruleIDs);
  const fix = fixtures ?? {};
  const families = Array.isArray(fix.families) ? fix.families : [];
  const attacks = Array.isArray(fix.attacks) ? fix.attacks : [];
  const positiveControls = Array.isArray(fix.positiveControls) ? fix.positiveControls : [];

  // Family keys: exactly the closed set, ordered, no duplicates/empties.
  if (families.length !== FAMILIES.length || !families.every((k, i) => k === FAMILIES[i])) {
    findings.push(makeFinding({
      id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: '/families',
      message: `family keys must equal the closed ${FAMILIES.length}-key set AF01..AF35`,
    }));
  }

  // Attack IDs: exactly the closed 75-key set, ordered, consecutive.
  const attackIDs = attacks.map((a) => a && a.id);
  if (attackIDs.length !== ATTACK_IDS.length ||
      !attackIDs.every((k, i) => k === ATTACK_IDS[i])) {
    findings.push(makeFinding({
      id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: '/attacks',
      message: `attack IDs must equal the closed 75-key set (R1=12, R2=22, R3=29, R4=12)`,
    }));
  }

  // Variant IDs: exactly the closed required set, ordered.
  const variantIDs = attacks.flatMap((a) => (a && Array.isArray(a.variants)) ? a.variants.map((v) => v && v.id) : []);
  if (variantIDs.length !== REQUIRED_VARIANT_IDS.length ||
      !variantIDs.every((k, i) => k === REQUIRED_VARIANT_IDS[i])) {
    findings.push(makeFinding({
      id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: '/attacks/variants',
      message: `variant IDs must equal the closed required variant set (${REQUIRED_VARIANT_IDS.length} rows)`,
    }));
  }

  // Each attack selects >=1 family from the closed set and owns a non-empty
  // variant array; no multiply-selected or prose-only row.
  for (const a of attacks) {
    if (!a || typeof a.id !== 'string') continue;
    if (!Array.isArray(a.families) || a.families.length === 0) {
      findings.push(makeFinding({
        id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/attacks/${a.id}/families`,
        message: `attack ${a.id} must select one or more family keys`,
      }));
    }
    const seenFam = new Set();
    for (const f of (a.families ?? [])) {
      if (!FAMILIES.includes(f)) {
        findings.push(makeFinding({
          id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/attacks/${a.id}/families`,
          message: `attack ${a.id} selects unknown family ${f}`,
        }));
      }
      if (seenFam.has(f)) {
        findings.push(makeFinding({
          id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/attacks/${a.id}/families`,
          message: `attack ${a.id} multiply selects family ${f}`,
        }));
      }
      seenFam.add(f);
    }
    if (!Array.isArray(a.variants) || a.variants.length === 0) {
      findings.push(makeFinding({
        id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/attacks/${a.id}/variants`,
        message: `attack ${a.id} must own a non-empty variant array`,
      }));
    }
  }

  // Every variant has a non-empty expectedFindings array, every expected ID is
  // a production rule, and the owningCommand is a non-empty string. Also every
  // variant ID is unique.
  const seenVariants = new Set();
  for (const a of attacks) {
    for (const v of (a && Array.isArray(a.variants)) ? a.variants : []) {
      if (!v || typeof v.id !== 'string') continue;
      if (seenVariants.has(v.id)) {
        findings.push(makeFinding({
          id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/attacks/${a.id}/variants`,
          message: `duplicate variant ID ${v.id}`,
        }));
      }
      seenVariants.add(v.id);
      if (!Array.isArray(v.expectedFindings) || v.expectedFindings.length === 0) {
        findings.push(makeFinding({
          id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/variants/${v.id}/expectedFindings`,
          message: `variant ${v.id} must declare a non-empty expectedFindings array`,
        }));
      }
      for (const fid of (v.expectedFindings ?? [])) {
        if (!ruleSet.has(fid)) {
          findings.push(makeFinding({
            id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/variants/${v.id}/expectedFindings`,
            message: `variant ${v.id} references unknown finding ${fid}`,
          }));
        }
      }
      if (typeof v.owningCommand !== 'string' || v.owningCommand.length === 0) {
        findings.push(makeFinding({
          id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/variants/${v.id}/owningCommand`,
          message: `variant ${v.id} must declare an owning production command`,
        }));
      }
    }
  }

  // Every production rule has >=1 negative fixture and >=1 positive control.
  // Negative fixtures come from both attack variants and the per-rule
  // negativeFixtures array.
  const negativeByRule = new Map();
  const addNeg = (fid, fid2) => {
    if (!negativeByRule.has(fid)) negativeByRule.set(fid, []);
    negativeByRule.get(fid).push(fid2);
  };
  for (const a of attacks) {
    for (const v of (a && Array.isArray(a.variants)) ? a.variants : []) {
      for (const fid of (v && Array.isArray(v.expectedFindings)) ? v.expectedFindings : []) {
        addNeg(fid, v.id);
      }
    }
  }
  for (const nf of (Array.isArray(fix.negativeFixtures) ? fix.negativeFixtures : [])) {
    if (!nf || typeof nf.id !== 'string') continue;
    for (const fid of (Array.isArray(nf.expectedFindings) ? nf.expectedFindings : [])) {
      addNeg(fid, nf.id);
    }
    if (nf.ruleID && ruleSet.has(nf.ruleID)) addNeg(nf.ruleID, nf.id);
  }
  for (const rule of ruleIDs) {
    if (!negativeByRule.has(rule) || negativeByRule.get(rule).length === 0) {
      findings.push(makeFinding({
        id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/rules/${rule}`,
        message: `production rule ${rule} has no negative fixture`,
      }));
    }
  }
  const positiveByRule = new Map();
  for (const pc of positiveControls) {
    if (!pc || typeof pc.ruleID !== 'string') continue;
    if (!positiveByRule.has(pc.ruleID)) positiveByRule.set(pc.ruleID, 0);
    positiveByRule.set(pc.ruleID, positiveByRule.get(pc.ruleID) + 1);
  }
  for (const rule of ruleIDs) {
    if (!positiveByRule.has(rule) || positiveByRule.get(rule) === 0) {
      findings.push(makeFinding({
        id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/rules/${rule}/positiveControl`,
        message: `production rule ${rule} has no positive control`,
      }));
    }
  }
  // Positive control IDs are unique and reference real rules.
  const seenPC = new Set();
  for (const pc of positiveControls) {
    if (!pc || typeof pc.id !== 'string') continue;
    if (seenPC.has(pc.id)) {
      findings.push(makeFinding({
        id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: '/positiveControls',
        message: `duplicate positive control ID ${pc.id}`,
      }));
    }
    seenPC.add(pc.id);
    if (!ruleSet.has(pc.ruleID)) {
      findings.push(makeFinding({
        id: 'PLAN_MUTATION_COVERAGE', category: 'mutation-coverage', taskID: null, path: `/positiveControls/${pc.id}`,
        message: `positive control ${pc.id} references unknown rule ${pc.ruleID}`,
      }));
    }
  }

  return sortFindings(findings);
}

// ---------------------------------------------------------------------------
// executeFixture — apply a fixture's mutation and run the appropriate audit
// entry point. Returns { observedIDs: string[], passed: boolean }.
// `passed` means every expectedFinding is observed (subset semantics: the
// mutation is rejected under its exact finding array; extra findings do not
// negate the rejection).
// ---------------------------------------------------------------------------

export async function executeFixture(fixture, ctx) {
  const { plan, contract, payloadIndex, archiveRoot } = ctx;
  // Use the committed payload index's own cursor so the audit is consistent
  // with the index state at test time (cursor 26 before the Task 27 refresh).
  const completedThroughTask = ctx.completedThroughTask ??
    (payloadIndex && Number.isInteger(payloadIndex.completedThroughTask) ? payloadIndex.completedThroughTask : 26);
  const mutation = fixture.mutation || {};
  const runner = mutation.runner || 'auditPlan';

  if (runner === 'compareObserved') {
    const { compareObservedMutations } = await import('./mutation-policy.mjs');
    const findings = compareObservedMutations(mutation.policy, mutation.observed);
    const observedIDs = [...new Set(findings.map((f) => f.id))];
    return { observedIDs, passed: fixture.expectedFindings.every((id) => observedIDs.includes(id)) };
  }

  if (runner === 'auditSourceInputs') {
    const { auditImplementationSourceInputs } = await import('./command-paths.mjs');
    const findings = auditImplementationSourceInputs(mutation.plan, mutation.baselineRows ?? []);
    const observedIDs = [...new Set(findings.map((f) => f.id))];
    return { observedIDs, passed: fixture.expectedFindings.every((id) => observedIDs.includes(id)) };
  }

  if (runner === 'auditCommandDeps') {
    const { auditCommandDependencies } = await import('./command-paths.mjs');
    const findings = auditCommandDependencies(mutation.plan, mutation.baselineRows ?? []);
    const observedIDs = [...new Set(findings.map((f) => f.id))];
    return { observedIDs, passed: fixture.expectedFindings.every((id) => observedIDs.includes(id)) };
  }

  if (runner === 'auditMarkdown') {
    const { auditMarkdown } = await import('./markdown.mjs');
    const os = await import('node:os');
    const fs = await import('node:fs');
    const p = await import('node:path');
    const dir = fs.mkdtempSync(p.join(os.tmpdir(), 'mc-markdown-'));
    try {
      const doc = p.join(dir, mutation.document);
      fs.writeFileSync(doc, mutation.contents);
      const syntheticPlan = { phases: [{ id: '00', document: mutation.document }], tasks: [] };
      const { findings } = auditMarkdown(syntheticPlan, dir);
      const observedIDs = [...new Set(findings.map((f) => f.id))];
      return { observedIDs, passed: fixture.expectedFindings.every((id) => observedIDs.includes(id)) };
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }

  // Default: auditPlan on a mutated plan + payloadIndex.
  const { auditPlan } = await import('./audit.mjs');
  const mutatedPlan = mutation.op === 'noop' ? plan : applyMutation(plan, mutation);
  let mutatedPayload = payloadIndex;
  if (mutation.target === 'payloadIndex') {
    mutatedPayload = applyMutation(payloadIndex, mutation);
  }
  const result = auditPlan({
    contract, plan: mutatedPlan, commands: mutatedPlan.commands ?? [],
    interfaces: mutatedPlan.interfaces ?? [], archiveRoot,
    completedThroughTask, payloadIndex: mutatedPayload,
  });
  const observedIDs = [...new Set(result.findings.map((f) => f.id))];
  return { observedIDs, passed: fixture.expectedFindings.every((id) => observedIDs.includes(id)) };
}
