// G6-R execution schema validator.
// Repository-owned, dependency-free. Enforces the closed ExecutionPlan contract
// defined in artifacts/monacode-g6r-execution-schema.json (JSON Schema 2020-12).
// validateExecutionPlan returns a sorted Finding[] and NEVER throws for data
// errors — malformed input yields findings, not exceptions.

import { makeFinding, sortFindings } from './findings.mjs';

// ---------------------------------------------------------------------------
// Closed value sets and patterns
// ---------------------------------------------------------------------------

export const STAGE_NAMES = [
  'preflight',
  'test-authoring',
  'red',
  'implementation',
  'green',
  'commit',
  'evidence',
];

const STEP_KINDS = [
  'controller-action',
  'authoring-operation',
  'verification-command',
  'source-acquisition',
  'implementation-operation',
];

const COMMAND_KINDS = ['process', 'all-success', 'pipeline'];
const AVAILABILITY_VALUES = ['local', 'remote', 'generated', 'inherited'];
const DISPOSITIONS = ['temporary', 'task-step'];
const LIFECYCLE_STATES = ['idle', 'running', 'complete', 'aborted'];
const FAILURE_CLASSES = ['assertion', 'compile', 'runtime', 'timeout', 'crash', 'signal'];
const CASE_SOURCES = ['baseline', 'dependency', 'task-step'];
const SENTINEL_BEHAVIORS = ['compile-fail', 'runtime-fail', 'test-fail'];
const FIXTURE_KINDS = ['inline', 'path'];

const TASK_ID_RE = /^P[0-9]{2}-T[0-9]{3}$/;
const COMMAND_ID_RE = /^P[0-9]{2}-T[0-9]{3}\.(RED|GREEN)\.[0-9]{3}$/;
const LEAF_ID_RE = /^P[0-9]{2}-T[0-9]{3}\.(RED|GREEN)\.[0-9]{3}\.PROC\.[0-9]{3}$/;
const HEX40_RE = /^[0-9a-f]{40}$/;
const HEX64_RE = /^[0-9a-f]{64}$/;
const PRODUCT_MSG_RE = /^monacode: complete P[0-9]{2}-T[0-9]{3}$/;
const EVIDENCE_MSG_RE = /^evidence\(monacode\): complete P[0-9]{2}-T[0-9]{3}$/;

const IDENTITY = { name: 'zhengrenzhe', email: 'zhengrenzhe0416@outlook.com' };

// ---------------------------------------------------------------------------
// Shape model for the additional-properties (closed-object) walker.
// Each type declares its allowed property set; the walker flags any data key
// not declared here. Discriminated unions resolve by the discriminator value.
// ---------------------------------------------------------------------------

const LEAF = { tag: 'leaf' };
const arr = (item) => ({ tag: 'arr', item });
const obj = (props) => ({ tag: 'obj', props });
const union = (disc, variants) => ({ tag: 'union', disc, variants });

const TYPES = {
  ExecutionPlan: obj({ planID: LEAF, baseCommit: LEAF, planHash: LEAF, tasks: arr('TaskRecord') }),
  TaskRecord: obj({
    taskID: LEAF,
    stages: arr('StageRecord'),
    testContract: 'TaskTestContract',
    completionAssertions: LEAF,
    workspace: 'TaskWorkspace',
    redScaffold: 'RedScaffold',
    productCommit: 'ProductCommitContract',
    evidenceCommit: 'EvidenceCommitContract',
  }),
  StageRecord: obj({ name: LEAF, steps: arr('StageStep') }),
  StageStep: union('kind', {
    'controller-action': 'StepControllerAction',
    'authoring-operation': 'StepAuthoring',
    'verification-command': 'StepVerification',
    'source-acquisition': 'StepSourceAcq',
    'implementation-operation': 'StepImplementation',
  }),
  StepControllerAction: obj({ kind: LEAF, action: LEAF }),
  StepAuthoring: obj({ kind: LEAF, operation: LEAF }),
  StepVerification: obj({ kind: LEAF, command: 'CommandSpec' }),
  StepSourceAcq: obj({ kind: LEAF, acquisition: 'SourceAcquisition' }),
  StepImplementation: obj({ kind: LEAF, operation: LEAF }),
  CommandSpec: obj({
    commandID: LEAF, kind: LEAF, networkMode: LEAF, timeoutMs: LEAF,
    leaves: arr('ProcessSpec'), pipefail: LEAF,
  }),
  ProcessSpec: obj({
    leafID: LEAF, executable: LEAF, toolchainRow: LEAF, args: LEAF, timeoutMs: LEAF,
  }),
  TaskTestContract: obj({ contractID: LEAF, cases: arr('TestCaseContract') }),
  TestCaseContract: obj({
    caseID: LEAF, file: 'PathInput', checker: LEAF, target: LEAF, testSymbol: LEAF,
    fixtures: 'Fixtures', assertions: arr('Assertion'), redLeafID: LEAF, greenLeafID: LEAF,
    inheritedOutput: LEAF, failureClass: LEAF, authoringOperation: LEAF, source: LEAF,
  }),
  PathInput: obj({ path: LEAF, availability: LEAF }),
  Fixtures: union('kind', { inline: 'FixturesInline', path: 'FixturesPath' }),
  FixturesInline: obj({ kind: LEAF, values: LEAF }),
  FixturesPath: obj({ kind: LEAF, path: LEAF, hash: LEAF }),
  Assertion: obj({ id: LEAF, operand: LEAF }),
  TaskWorkspace: obj({
    ownershipToken: LEAF, taskRoot: LEAF, planHash: LEAF, taskHash: LEAF, baseHash: LEAF,
    currentStage: LEAF, lifecycleState: LEAF,
  }),
  RedScaffold: obj({
    sourcePath: LEAF, declarationText: LEAF, declarationHash: LEAF, sentinelBehavior: LEAF,
    createOwner: LEAF, replacementOwner: LEAF, redAssertionID: LEAF, finalAbsenceAssertion: LEAF,
  }),
  ProductCommitContract: obj({
    author: 'Identity', committer: 'Identity', message: LEAF, preflightBaseParent: LEAF,
    stagedProductPaths: LEAF, hooksDisabled: LEAF, signingDisabled: LEAF, evidenceExcluded: LEAF,
  }),
  EvidenceCommitContract: obj({
    author: 'Identity', committer: 'Identity', message: LEAF, parentCommit: LEAF,
    firstParentSuccessor: LEAF, stagedEvidencePath: LEAF, laterFirstParentTouches: LEAF,
    hooksDisabled: LEAF, signingDisabled: LEAF, selectorMode: LEAF, prohibitsSelfEmbedding: LEAF,
    evidenceSchema: LEAF, verifiedAssertions: LEAF,
  }),
  Identity: obj({ name: LEAF, email: LEAF }),
  SourceAcquisition: obj({
    url: LEAF, allowedHost: LEAF, redirectChain: LEAF, expectedBytes: LEAF, maxBytes: LEAF,
    sha256: LEAF, license: LEAF, outputPath: LEAF, disposition: LEAF, taskOwner: LEAF,
    stageOwner: LEAF, timeoutMs: LEAF, existingOutputBehavior: LEAF, archive: 'ArchiveSpec',
  }),
  ArchiveSpec: obj({
    format: LEAF, entryCount: LEAF, exactExpandedBytes: LEAF, maxExpandedBytes: LEAF,
    extractionRoot: LEAF, rejectAbsolute: LEAF, rejectTraversal: LEAF, rejectSymlinks: LEAF,
    rejectHardLinks: LEAF, rejectDevices: LEAF, rejectDuplicateNormalized: LEAF,
    rejectComponentCollisions: LEAF, rejectProbeCollisions: LEAF,
  }),
};

function walkAdditional(value, typeRef, path, taskID, findings) {
  const type = typeof typeRef === 'string' ? TYPES[typeRef] : typeRef;
  if (!type) return;
  if (type.tag === 'leaf') return;
  if (type.tag === 'arr') {
    if (!Array.isArray(value)) return;
    for (let i = 0; i < value.length; i++) {
      walkAdditional(value[i], type.item, `${path}/${i}`, taskID, findings);
    }
    return;
  }
  if (type.tag === 'union') {
    if (typeof value !== 'object' || value === null) return;
    const discVal = value[type.disc];
    const variantRef = type.variants[discVal];
    if (variantRef) walkAdditional(value, variantRef, path, taskID, findings);
    return;
  }
  if (type.tag === 'obj') {
    if (typeof value !== 'object' || value === null) return;
    for (const key of Object.keys(value)) {
      const childRef = type.props[key];
      if (childRef === undefined) {
        findings.push(makeFinding({
          id: 'PLAN_SCHEMA_ADDITIONAL_PROPERTY', category: 'structure', taskID,
          path: `${path}/${key}`,
          message: `additional property "${key}" is not permitted at this layer`,
        }));
      } else {
        walkAdditional(value[key], childRef, `${path}/${key}`, taskID, findings);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const isObj = (v) => v !== null && typeof v === 'object';
const isNonEmptyStr = (v) => typeof v === 'string' && v.length > 0;
const isPosInt = (v) => Number.isInteger(v) && v > 0;
const matchIdent = (o) => isObj(o) && o.name === IDENTITY.name && o.email === IDENTITY.email;

// ---------------------------------------------------------------------------
// Per-task semantic checks. Each returns a single Finding or null, emitting
// at most one finding so a single seeded defect never cascades.
// ---------------------------------------------------------------------------

function checkStageCompatibility(byName, taskID) {
  const stepsOf = (name) => {
    const s = byName[name];
    return s && Array.isArray(s.steps) ? s.steps : null;
  };
  const compat = (stage, msg) => makeFinding({
    id: 'PLAN_STAGE_COMPATIBILITY', category: 'semantic', taskID, path: '/stages',
    message: `stage "${stage}" ${msg}`,
  });
  const stepInvalid = (stage) => makeFinding({
    id: 'PLAN_STAGE_STEP_INVALID', category: 'structure', taskID, path: '/stages',
    message: `stage "${stage}" contains a null or non-object step element`,
  });
  const pf = stepsOf('preflight');
  if (!pf || pf.length !== 1) return compat('preflight', 'must contain exactly one begin-task controller action');
  if (!isObj(pf[0])) return stepInvalid('preflight');
  if (pf[0].kind !== 'controller-action' || pf[0].action !== 'begin-task')
    return compat('preflight', 'must contain exactly one begin-task controller action');
  const ta = stepsOf('test-authoring');
  if (!ta || ta.length < 1 || !ta.every((s) => s && s.kind === 'authoring-operation'))
    return compat('test-authoring', 'must contain one or more authoring operations');
  const rd = stepsOf('red');
  if (!rd || rd.length !== 1) return compat('red', 'must contain exactly one verification command');
  if (!isObj(rd[0])) return stepInvalid('red');
  if (rd[0].kind !== 'verification-command')
    return compat('red', 'must contain exactly one verification command');
  const im = stepsOf('implementation');
  if (!im || im.length < 1 || !im.some((s) => s && s.kind === 'implementation-operation') ||
      !im.every((s) => s && (s.kind === 'implementation-operation' || s.kind === 'source-acquisition')))
    return compat('implementation', 'must contain at least one implementation operation (optionally source acquisitions)');
  const gr = stepsOf('green');
  if (!gr || gr.length !== 1) return compat('green', 'must contain exactly one verification command');
  if (!isObj(gr[0])) return stepInvalid('green');
  if (gr[0].kind !== 'verification-command')
    return compat('green', 'must contain exactly one verification command');
  const cm = stepsOf('commit');
  if (!cm || cm.length !== 1) return compat('commit', 'must contain exactly one commit-task controller action');
  if (!isObj(cm[0])) return stepInvalid('commit');
  if (cm[0].kind !== 'controller-action' || cm[0].action !== 'commit-task')
    return compat('commit', 'must contain exactly one commit-task controller action');
  const ev = stepsOf('evidence');
  if (!ev || ev.length !== 1) return compat('evidence', 'must contain exactly one finalize-evidence controller action');
  if (!isObj(ev[0])) return stepInvalid('evidence');
  if (ev[0].kind !== 'controller-action' || ev[0].action !== 'finalize-evidence')
    return compat('evidence', 'must contain exactly one finalize-evidence controller action');
  return null;
}

function checkCommandShape(command, path, taskID) {
  const shape = (msg) => makeFinding({
    id: 'PLAN_COMMAND_SHAPE', category: 'structure', taskID, path, message: msg,
  });
  if (!isObj(command)) return shape('command must be a CommandSpec object');
  if (typeof command.commandID !== 'string' || !COMMAND_ID_RE.test(command.commandID))
    return shape('commandID must match ^P[0-9]{2}-T[0-9]{3}\\.(RED|GREEN)\\.[0-9]{3}$');
  if (!COMMAND_KINDS.includes(command.kind))
    return shape(`command kind must be one of ${COMMAND_KINDS.join('|')}`);
  if (command.networkMode !== 'forbidden')
    return shape('verification command networkMode must be "forbidden"');
  if (!isPosInt(command.timeoutMs))
    return shape('timeoutMs must be a positive integer');
  if (!Array.isArray(command.leaves))
    return shape('leaves must be an array of ProcessSpec');
  if (command.kind === 'process' && command.leaves.length !== 1)
    return shape('process command must have exactly one leaf');
  if ((command.kind === 'all-success' || command.kind === 'pipeline') && command.leaves.length < 2)
    return shape(`${command.kind} command must have at least two leaves`);
  if (command.kind === 'pipeline' && command.pipefail !== true)
    return shape('pipeline command must carry pipefail: true');
  if (command.kind !== 'pipeline' && command.pipefail !== undefined)
    return shape('only pipeline commands may carry pipefail');
  for (const leaf of command.leaves) {
    if (!isObj(leaf)) return shape('each leaf must be a ProcessSpec object');
    if (typeof leaf.leafID !== 'string' || !LEAF_ID_RE.test(leaf.leafID))
      return shape('leafID must match ^<commandID>\\.PROC\\.[0-9]{3}$');
    if (!leaf.leafID.startsWith(command.commandID + '.PROC.'))
      return shape('leafID must extend its parent commandID');
    if (typeof leaf.executable !== 'string' || !leaf.executable.startsWith('/'))
      return shape('leaf executable must be an absolute path');
    if (!isNonEmptyStr(leaf.toolchainRow))
      return shape('leaf must select one toolchain-lock row');
    if (!isPosInt(leaf.timeoutMs))
      return shape('leaf timeoutMs must be a positive integer');
  }
  return null;
}

function checkPathAvailability(task, tpath, taskID) {
  const out = [];
  const cases = task.testContract && task.testContract.cases;
  if (!Array.isArray(cases)) return out;
  cases.forEach((c, ci) => {
    if (!isObj(c) || !isObj(c.file)) return;
    if (!AVAILABILITY_VALUES.includes(c.file.availability)) {
      out.push(makeFinding({
        id: 'PLAN_PATH_AVAILABILITY', category: 'structure', taskID,
        path: `${tpath}/testContract/cases/${ci}/file/availability`,
        message: `unknown availability class "${c.file.availability}"`,
      }));
    }
  });
  return out;
}

function checkProductCommit(task, tpath, taskID) {
  const pc = task.productCommit;
  const f = (msg) => makeFinding({
    id: 'PLAN_PRODUCT_COMMIT_CONTRACT', category: 'contract', taskID,
    path: `${tpath}/productCommit`, message: msg,
  });
  if (!isObj(pc)) return f('must be a ProductCommitContract object');
  if (!matchIdent(pc.author)) return f('author identity must be zhengrenzhe <zhengrenzhe0416@outlook.com>');
  if (!matchIdent(pc.committer)) return f('committer identity must be zhengrenzhe <zhengrenzhe0416@outlook.com>');
  if (typeof pc.message !== 'string' || !PRODUCT_MSG_RE.test(pc.message))
    return f('message must match ^monacode: complete P[0-9]{2}-T[0-9]{3}$');
  if (pc.message !== 'monacode: complete ' + taskID)
    return f('message must reference the enclosing task ID');
  if (typeof pc.preflightBaseParent !== 'string' || !HEX40_RE.test(pc.preflightBaseParent))
    return f('preflightBaseParent must be the 40-hex preflight base commit');
  if (!Array.isArray(pc.stagedProductPaths) || pc.stagedProductPaths.length === 0 ||
      !pc.stagedProductPaths.every((p) => typeof p === 'string' && p.length > 0 && !p.startsWith('/')))
    return f('stagedProductPaths must be non-empty repo-relative paths');
  if (pc.hooksDisabled !== true) return f('hooks must be disabled');
  if (pc.signingDisabled !== true) return f('signing must be disabled');
  if (pc.evidenceExcluded !== true) return f('evidence must be excluded from the product commit');
  return null;
}

function checkEvidenceCommit(task, tpath, taskID) {
  const ec = task.evidenceCommit;
  const f = (msg) => makeFinding({
    id: 'PLAN_EVIDENCE_CONTRACT', category: 'contract', taskID,
    path: `${tpath}/evidenceCommit`, message: msg,
  });
  if (!isObj(ec)) return f('must be an EvidenceCommitContract object');
  if (!matchIdent(ec.author)) return f('author identity must be zhengrenzhe <zhengrenzhe0416@outlook.com>');
  if (!matchIdent(ec.committer)) return f('committer identity must be zhengrenzhe <zhengrenzhe0416@outlook.com>');
  if (typeof ec.message !== 'string' || !EVIDENCE_MSG_RE.test(ec.message))
    return f('message must match ^evidence\\(monacode\\): complete P[0-9]{2}-T[0-9]{3}$');
  if (ec.message !== 'evidence(monacode): complete ' + taskID)
    return f('message must reference the enclosing task ID');
  if (typeof ec.parentCommit !== 'string' || !HEX40_RE.test(ec.parentCommit))
    return f('parentCommit must be the 40-hex sole product commit');
  if (ec.firstParentSuccessor !== 'immediate')
    return f('firstParentSuccessor must select the immediate first-parent successor');
  if (!isNonEmptyStr(ec.stagedEvidencePath))
    return f('stagedEvidencePath must be the sole task evidence path');
  if (ec.laterFirstParentTouches !== 0)
    return f('laterFirstParentTouches must be zero');
  if (ec.hooksDisabled !== true) return f('hooks must be disabled');
  if (ec.signingDisabled !== true) return f('signing must be disabled');
  if (ec.selectorMode !== 'external-git') return f('selectorMode must be external-git');
  if (ec.prohibitsSelfEmbedding !== true)
    return f('must prohibit embedding its own blob hash or commit ID in the evidence JSON');
  if (!isNonEmptyStr(ec.evidenceSchema))
    return f('evidenceSchema must reference the evidence JSON schema');
  const ca = task.completionAssertions;
  if (!Array.isArray(ec.verifiedAssertions) || !Array.isArray(ca) ||
      ec.verifiedAssertions.length !== ca.length ||
      !ec.verifiedAssertions.every((v, i) => v === ca[i]))
    return f('verifiedAssertions must equal the task completionAssertions');
  return null;
}

function checkWorkspace(task, tpath, taskID) {
  const ws = task.workspace;
  const f = (msg) => makeFinding({
    id: 'PLAN_WORKSPACE', category: 'contract', taskID, path: `${tpath}/workspace`, message: msg,
  });
  if (!isObj(ws)) return f('must be a TaskWorkspace object');
  if (typeof ws.ownershipToken !== 'string' || !HEX64_RE.test(ws.ownershipToken))
    return f('ownershipToken must be an opaque 256-bit (64 hex) token');
  if (typeof ws.taskRoot !== 'string' || !ws.taskRoot.startsWith('/'))
    return f('taskRoot must be a realpath-normalized absolute path');
  if (typeof ws.planHash !== 'string' || !HEX40_RE.test(ws.planHash)) return f('planHash must be 40 hex');
  if (typeof ws.taskHash !== 'string' || !HEX40_RE.test(ws.taskHash)) return f('taskHash must be 40 hex');
  if (typeof ws.baseHash !== 'string' || !HEX40_RE.test(ws.baseHash)) return f('baseHash must be 40 hex');
  if (!STAGE_NAMES.includes(ws.currentStage)) return f('currentStage must be a G6-R stage name');
  if (!LIFECYCLE_STATES.includes(ws.lifecycleState)) return f('lifecycleState must be a closed lifecycle state');
  return null;
}

function checkScaffold(task, tpath, taskID) {
  const rs = task.redScaffold;
  const f = (msg) => makeFinding({
    id: 'PLAN_SCAFFOLD', category: 'contract', taskID, path: `${tpath}/redScaffold`, message: msg,
  });
  if (!isObj(rs)) return f('must be a RedScaffold object');
  if (!isNonEmptyStr(rs.sourcePath)) return f('sourcePath must be a non-empty path');
  if (typeof rs.declarationText !== 'string') return f('declarationText must be a string');
  if (typeof rs.declarationHash !== 'string' || !/^sha256:[0-9a-f]{64}$/.test(rs.declarationHash))
    return f('declarationHash must be sha256:<64 hex>');
  if (!SENTINEL_BEHAVIORS.includes(rs.sentinelBehavior)) return f('sentinelBehavior must be a closed value');
  if (rs.createOwner !== 'test-authoring') return f('createOwner must be test-authoring');
  if (rs.replacementOwner !== 'implementation') return f('replacementOwner must be implementation');
  if (!isNonEmptyStr(rs.redAssertionID)) return f('redAssertionID must be non-empty');
  if (!isNonEmptyStr(rs.finalAbsenceAssertion)) return f('finalAbsenceAssertion must be non-empty');
  return null;
}

function checkTestContract(task, tpath, taskID) {
  const tc = task.testContract;
  const f = (msg) => makeFinding({
    id: 'PLAN_TEST_CONTRACT', category: 'contract', taskID, path: `${tpath}/testContract`, message: msg,
  });
  if (!Array.isArray(task.completionAssertions) || task.completionAssertions.length < 2 || task.completionAssertions.length > 4 ||
      !task.completionAssertions.every(isNonEmptyStr))
    return f('completionAssertions must be a 2-to-4 element array of assertion IDs');
  if (!isObj(tc)) return f('must be a TaskTestContract object');
  if (!isNonEmptyStr(tc.contractID)) return f('contractID must be non-empty');
  if (!Array.isArray(tc.cases) || tc.cases.length === 0) return f('cases must be a non-empty array');
  for (const c of tc.cases) {
    if (!isObj(c)) return f('each case must be an object');
    if (!isNonEmptyStr(c.caseID)) return f('caseID must be non-empty');
    if (!isObj(c.file)) return f('case file must be a PathInput');
    if (!isNonEmptyStr(c.file.path)) return f('case file path must be non-empty');
    if (!isNonEmptyStr(c.checker)) return f('checker must be non-empty');
    if (!isNonEmptyStr(c.target)) return f('target must be non-empty');
    if (!isNonEmptyStr(c.testSymbol)) return f('testSymbol or Node name pattern must be non-empty');
    if (!isObj(c.fixtures) || !FIXTURE_KINDS.includes(c.fixtures.kind)) return f('fixtures kind must be closed');
    if (c.fixtures.kind === 'inline' && !isObj(c.fixtures.values)) return f('inline fixtures require values');
    if (c.fixtures.kind === 'path' && (!isNonEmptyStr(c.fixtures.path) || !isNonEmptyStr(c.fixtures.hash)))
      return f('path fixtures require path and hash');
    if (!Array.isArray(c.assertions) || c.assertions.length === 0) return f('assertions must be a non-empty ordered array');
    for (const a of c.assertions) {
      if (!isObj(a) || !isNonEmptyStr(a.id) || !isNonEmptyStr(a.operand))
        return f('each assertion requires a non-empty id and operand');
    }
    if (typeof c.redLeafID !== 'string' || !LEAF_ID_RE.test(c.redLeafID)) return f('redLeafID must match the leaf pattern');
    if (typeof c.greenLeafID !== 'string' || !LEAF_ID_RE.test(c.greenLeafID)) return f('greenLeafID must match the leaf pattern');
    if (typeof c.inheritedOutput !== 'boolean') return f('inheritedOutput must be a boolean');
    if (!FAILURE_CLASSES.includes(c.failureClass)) return f('failureClass must be a closed value');
    if (!isNonEmptyStr(c.authoringOperation)) return f('authoringOperation must be non-empty');
    if (!CASE_SOURCES.includes(c.source)) return f('source must be baseline|dependency|task-step');
  }
  return null;
}

function checkSourceAcquisitions(byName, tpath, taskID) {
  const out = [];
  const im = byName.implementation;
  if (!im || !Array.isArray(im.steps)) return out;
  for (let si = 0; si < im.steps.length; si++) {
    const step = im.steps[si];
    if (!step || step.kind !== 'source-acquisition') continue;
    const acq = step.acquisition;
    const path = `${tpath}/stages/implementation/steps/${si}/acquisition`;
    const f = (msg) => makeFinding({
      id: 'PLAN_SOURCE_ACQUISITION', category: 'contract', taskID, path, message: msg,
    });
    if (!isObj(acq)) { out.push(f('must be a SourceAcquisition object')); continue; }
    if (typeof acq.url !== 'string' || !/^https:\/\//.test(acq.url) || /:[^/@]*@/.test(acq.url))
      { out.push(f('url must be HTTPS without credentials')); continue; }
    if (!isNonEmptyStr(acq.allowedHost)) { out.push(f('allowedHost must be exact')); continue; }
    if (!Array.isArray(acq.redirectChain)) { out.push(f('redirectChain must be an exact array')); continue; }
    if (!isPosInt(acq.expectedBytes)) { out.push(f('expectedBytes must be positive')); continue; }
    if (!isPosInt(acq.maxBytes) || acq.maxBytes < acq.expectedBytes) { out.push(f('maxBytes must be >= expectedBytes')); continue; }
    if (typeof acq.sha256 !== 'string' || !/^sha256:[0-9a-f]{64}$/.test(acq.sha256)) { out.push(f('sha256 must be sha256:<64 hex>')); continue; }
    if (!isNonEmptyStr(acq.license)) { out.push(f('license identity required')); continue; }
    if (!isNonEmptyStr(acq.outputPath)) { out.push(f('outputPath required')); continue; }
    if (!DISPOSITIONS.includes(acq.disposition)) { out.push(f('disposition must be temporary|task-step')); continue; }
    if (!isNonEmptyStr(acq.taskOwner) || !isNonEmptyStr(acq.stageOwner)) { out.push(f('task/stage owner required')); continue; }
    if (!isPosInt(acq.timeoutMs)) { out.push(f('timeoutMs must be positive')); continue; }
    if (acq.existingOutputBehavior !== 'require-same-hash') { out.push(f('existingOutputBehavior must be require-same-hash')); continue; }
    if (acq.archive !== undefined) {
      const ar = acq.archive;
      const af = (msg) => makeFinding({
        id: 'PLAN_SOURCE_ARCHIVE_INVALID', category: 'contract', taskID, path: `${path}/archive`, message: msg,
      });
      if (!isObj(ar)) { out.push(af('archive must be an ArchiveSpec object')); continue; }
      if (!isNonEmptyStr(ar.format)) { out.push(af('format must be a non-empty string')); continue; }
      if (!isPosInt(ar.entryCount)) { out.push(af('entryCount must be a positive integer')); continue; }
      if (!isPosInt(ar.exactExpandedBytes)) { out.push(af('exactExpandedBytes must be a positive integer')); continue; }
      if (!isPosInt(ar.maxExpandedBytes) || ar.maxExpandedBytes < ar.exactExpandedBytes) { out.push(af('maxExpandedBytes must be >= exactExpandedBytes')); continue; }
      if (!isNonEmptyStr(ar.extractionRoot)) { out.push(af('extractionRoot must be a non-empty path')); continue; }
      const REJECT_FLAGS = [
        'rejectAbsolute', 'rejectTraversal', 'rejectSymlinks', 'rejectHardLinks',
        'rejectDevices', 'rejectDuplicateNormalized', 'rejectComponentCollisions', 'rejectProbeCollisions',
      ];
      let badFlag = null;
      for (const fl of REJECT_FLAGS) {
        if (ar[fl] !== true) { badFlag = fl; break; }
      }
      if (badFlag) { out.push(af(`archive rejection flag ${badFlag} must be true`)); continue; }
    }
  }
  return out;
}

function checkLeafSelection(task, byName, tpath, taskID) {
  const leafIDs = new Set();
  for (const stageName of ['red', 'green']) {
    const stage = byName[stageName];
    if (!stage || !Array.isArray(stage.steps)) continue;
    for (const step of stage.steps) {
      if (!step || step.kind !== 'verification-command' || !isObj(step.command) || !Array.isArray(step.command.leaves)) continue;
      for (const leaf of step.command.leaves) {
        if (leaf && typeof leaf.leafID === 'string') leafIDs.add(leaf.leafID);
      }
    }
  }
  const refs = [];
  const cases = task.testContract && task.testContract.cases;
  if (Array.isArray(cases)) {
    for (const c of cases) {
      if (!isObj(c)) continue;
      if (typeof c.redLeafID === 'string') refs.push(c.redLeafID);
      if (typeof c.greenLeafID === 'string') refs.push(c.greenLeafID);
    }
  }
  for (const leafID of leafIDs) {
    const count = refs.filter((r) => r === leafID).length;
    if (count !== 1) return makeFinding({
      id: 'PLAN_LEAF_SELECTION', category: 'semantic', taskID, path: `${tpath}/testContract`,
      message: `leaf ${leafID} must be selected exactly once`,
    });
  }
  for (const r of refs) {
    if (!leafIDs.has(r)) return makeFinding({
      id: 'PLAN_LEAF_SELECTION', category: 'semantic', taskID, path: `${tpath}/testContract`,
      message: `test case references unknown leaf ${r}`,
    });
  }
  return null;
}

// ---------------------------------------------------------------------------
// Per-task validation
// ---------------------------------------------------------------------------

function validateTask(task, ti, findings) {
  const tpath = `/tasks/${ti}`;
  if (!isObj(task)) {
    findings.push(makeFinding({ id: 'PLAN_TYPE', category: 'structure', path: tpath, message: 'task must be an object' }));
    return;
  }
  const taskID = (typeof task.taskID === 'string' && TASK_ID_RE.test(task.taskID)) ? task.taskID : null;
  const stages = task.stages;
  if (!Array.isArray(stages)) {
    findings.push(makeFinding({ id: 'PLAN_TYPE', category: 'structure', taskID, path: `${tpath}/stages`, message: 'stages must be an array' }));
    return;
  }
  const names = stages.map((s) => (isObj(s) && typeof s.name === 'string') ? s.name : null);
  const validNames = names.filter((n) => n !== null);
  const nameSet = new Set(validNames);
  const setWrong = names.length !== STAGE_NAMES.length ||
    nameSet.size !== STAGE_NAMES.length ||
    validNames.some((n) => !STAGE_NAMES.includes(n));
  if (setWrong) {
    findings.push(makeFinding({
      id: 'PLAN_STAGE_SET', category: 'structure', taskID, path: `${tpath}/stages`,
      message: 'stage set must be exactly preflight,test-authoring,red,implementation,green,commit,evidence',
    }));
    return; // structural gate: skip remaining task-level semantic checks
  }
  if (names.join('|') !== STAGE_NAMES.join('|')) {
    findings.push(makeFinding({
      id: 'PLAN_STAGE_ORDER', category: 'structure', taskID, path: `${tpath}/stages`,
      message: 'stages must appear in the canonical G6-R order',
    }));
  }
  const byName = {};
  for (const s of stages) byName[s.name] = s;

  const compat = checkStageCompatibility(byName, taskID);
  if (compat) findings.push(compat);

  const commandFindings = [];
  for (const stageName of ['red', 'green']) {
    const stage = byName[stageName];
    if (!stage || !Array.isArray(stage.steps)) continue;
    for (let si = 0; si < stage.steps.length; si++) {
      const step = stage.steps[si];
      if (!step || step.kind !== 'verification-command') continue;
      const f = checkCommandShape(step.command, `${tpath}/stages/${stageName}/steps/${si}/command`, taskID);
      if (f) commandFindings.push(f);
    }
  }
  findings.push(...commandFindings);

  findings.push(...checkPathAvailability(task, tpath, taskID));
  findings.push(...checkSourceAcquisitions(byName, tpath, taskID));

  const pc = checkProductCommit(task, tpath, taskID);
  if (pc) findings.push(pc);
  const ec = checkEvidenceCommit(task, tpath, taskID);
  if (ec) findings.push(ec);
  const ws = checkWorkspace(task, tpath, taskID);
  if (ws) findings.push(ws);
  const rs = checkScaffold(task, tpath, taskID);
  if (rs) findings.push(rs);
  const tc = checkTestContract(task, tpath, taskID);
  if (tc) findings.push(tc);

  // Leaf selection is gated on every command being well-formed; a malformed
  // command cannot contribute trustworthy leaf IDs.
  if (commandFindings.length === 0 && !compat) {
    const lf = checkLeafSelection(task, byName, tpath, taskID);
    if (lf) findings.push(lf);
  }
}

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/**
 * Validate an ExecutionPlan record against the closed G6-R schema.
 * Returns a deterministically sorted Finding[]. Never throws for data errors.
 * @param {unknown} value
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function validateExecutionPlan(value) {
  const findings = [];
  if (!isObj(value)) {
    findings.push(makeFinding({ id: 'PLAN_TYPE', category: 'structure', path: '', message: 'plan must be an object' }));
    return sortFindings(findings);
  }
  // Closed-object walk across the entire tree (additionalProperties: false at every layer).
  walkAdditional(value, 'ExecutionPlan', '', null, findings);
  if (!Array.isArray(value.tasks) || value.tasks.length === 0) {
    findings.push(makeFinding({ id: 'PLAN_TYPE', category: 'structure', path: '/tasks', message: 'plan.tasks must be a non-empty array' }));
    return sortFindings(findings);
  }
  for (let i = 0; i < value.tasks.length; i++) {
    validateTask(value.tasks[i], i, findings);
  }
  return sortFindings(findings);
}
