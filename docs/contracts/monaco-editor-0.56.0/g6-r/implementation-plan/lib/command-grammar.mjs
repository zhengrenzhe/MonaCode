// G6-R closed command grammar and G5-R converter.
// Converts the 400 free-form G5-R shell-command records into the structured
// CommandSpec records (process / all-success / pipeline) defined by the Task 3
// schema. Every leaf is pinned to an absolute toolchain executable; the 20
// inherited Node-test argv arrays are normalized from file-before-option to
// option-before-file; P00-T001's checker leaf is rewritten to the G6-R runtime
// baseline. auditCommandSpec rejects forbidden shell and malformed structure.

import { makeFinding, sortFindings } from './findings.mjs';

// ---------------------------------------------------------------------------
// Pinned toolchain (closed: executables + toolchain-lock rows)
// ---------------------------------------------------------------------------

const NODE_BIN = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const XCRUN_BIN = '/usr/bin/xcrun';
const TOOLCHAIN_SWIFT = 'xcrun-swift-6.0-macos-26';
const TOOLCHAIN_NODE = 'node-26.7.0';
const VALID_EXECUTABLES = new Set([NODE_BIN, XCRUN_BIN]);

const COMMAND_KINDS = ['process', 'all-success', 'pipeline'];
const LEAF_FORMS = ['swift-test', 'node-test', 'node-script', 'swift-package'];
const FAILURE_CLASSES = ['behavioral', 'structural', 'package-graph', 'provenance', 'qualification'];

// P00-T001 rewrite target: the G5-R checker path never existed; the G6-R
// runtime checker is the baseline package-graph verifier.
const G5R_PACKAGE_GRAPH_CHECKER = 'Tools/PlanChecks/assert-package-graph.mjs';
const G6R_PACKAGE_GRAPH_CHECKER =
  'docs/contracts/monaco-editor-0.56.0/g6-r/implementation-plan/runtime/assert-package-graph.mjs';

// Forbidden shell tokens a closed leaf argv must never carry.
const COMPOSITION_TOKENS = ['&&', '||', '|', ';'];
const SUBSTITUTION_RE = /\$\(|`/;
const GLOB_RE = /\*/;
const INTERACTIVE_FLAGS = new Set(['-i', '--interactive', '--prompt']);

const isObj = (v) => v !== null && typeof v === 'object';
const isPosInt = (v) => Number.isInteger(v) && v > 0;

// ---------------------------------------------------------------------------
// parseObservedG5Command — topology classification
// ---------------------------------------------------------------------------

/**
 * Split an observed G5-R run string into its topology and leaf run strings.
 * @param {string} run
 * @returns {{topology:'process'|'all-success'|'pipeline', leaves:string[]}}
 */
export function parseObservedG5Command(run) {
  const r = String(run).trim();
  if (r.length === 0) throw new Error('PLAN_COMMAND_FORM_UNSUPPORTED empty-run');
  const hasPipe = r.includes(' | ');
  const hasAmp = r.includes(' && ');
  if (hasPipe && hasAmp) {
    throw new Error('PLAN_COMMAND_FORM_UNSUPPORTED mixed-composition');
  }
  if (hasPipe) {
    const leaves = r.split(' | ').map((s) => s.trim()).filter(Boolean);
    if (leaves.length < 2) throw new Error('PLAN_COMMAND_FORM_UNSUPPORTED pipeline-single');
    return { topology: 'pipeline', leaves };
  }
  if (hasAmp) {
    const leaves = r.split(' && ').map((s) => s.trim()).filter(Boolean);
    if (leaves.length < 2) throw new Error('PLAN_COMMAND_FORM_UNSUPPORTED all-success-single');
    return { topology: 'all-success', leaves };
  }
  return { topology: 'process', leaves: [r] };
}

// ---------------------------------------------------------------------------
// Leaf tokenization and normalization
// ---------------------------------------------------------------------------

function tokenize(run) {
  return String(run).trim().split(/\s+/).filter(Boolean);
}

/**
 * Normalize an inherited Node-test argv from the G5-R file-before-option form
 * `['--test', FILE, '--test-name-pattern', VALUE]` to the G6-R option-before-file
 * form `['--test', '--test-name-pattern', VALUE, FILE]`. Every other token
 * retains order. Returns the normalized argv and whether a reorder occurred.
 * @param {string[]} nodeArgs
 * @returns {{args:string[], reordered:boolean}}
 */
function normalizeNodeTestArgs(nodeArgs) {
  const pi = nodeArgs.indexOf('--test-name-pattern');
  if (pi <= 0) return { args: nodeArgs.slice(), reordered: false };
  // Already normalized: --test --test-name-pattern VALUE FILE ...
  if (nodeArgs[1] === '--test-name-pattern') return { args: nodeArgs.slice(), reordered: false };
  // Inherited (unnormalized): --test FILE --test-name-pattern VALUE [rest...]
  const fileToken = nodeArgs[1];
  const patternValue = nodeArgs[pi + 1];
  const rest = nodeArgs.slice(pi + 2);
  return {
    args: ['--test', '--test-name-pattern', patternValue, fileToken, ...rest],
    reordered: true,
  };
}

function rewritePackageGraphChecker(args) {
  if (args.length > 0 && args[0] === G5R_PACKAGE_GRAPH_CHECKER) {
    return [G6R_PACKAGE_GRAPH_CHECKER, ...args.slice(1)];
  }
  return args.slice();
}

function scratchPathFor(leafID) {
  return `/tmp/monacode-planctl/${leafID}`;
}

function leafTimeoutMs(form, phase) {
  if (phase === '09') return 1_800_000;
  if (form === 'swift-test' || form === 'swift-package') return 600_000;
  return 120_000;
}

function extractDeclaredPaths(args, form) {
  const paths = [];
  if (form === 'swift-test' || form === 'swift-package') paths.push('Package.swift');
  for (const a of args) {
    if ((a.endsWith('.mjs') || a.endsWith('.swift') || a === 'Package.swift') && !paths.includes(a)) {
      paths.push(a);
    }
  }
  return paths;
}

/**
 * Convert one leaf run string into a ProcessSpec (enriched with the audit
 * fields `form`, `stage`, `optionReorder`, and `declaredPaths`).
 * @param {{parentID:string, leafIndex:number, task:object, run:string}} input
 * @returns {object}
 */
function convertLeaf({ parentID, leafIndex, task, run }) {
  const leafID = `${parentID}.PROC.${String(leafIndex + 1).padStart(3, '0')}`;
  const toks = tokenize(run);
  if (toks.length === 0) throw new Error(`PLAN_COMMAND_FORM_UNSUPPORTED empty-leaf ${leafID}`);
  const stage = parentID.includes('.RED.') ? 'red' : 'green';

  let form, executable, toolchainRow, args, optionReorder = false;

  if (toks[0] === 'swift' && toks[1] === 'test') {
    form = 'swift-test';
    executable = XCRUN_BIN;
    toolchainRow = TOOLCHAIN_SWIFT;
    args = [...toks, '--scratch-path', scratchPathFor(leafID)];
  } else if (toks[0] === 'swift' && toks[1] === 'package') {
    form = 'swift-package';
    executable = XCRUN_BIN;
    toolchainRow = TOOLCHAIN_SWIFT;
    args = toks.slice();
  } else if (toks[0] === 'node' && toks[1] === '--test') {
    form = 'node-test';
    executable = NODE_BIN;
    toolchainRow = TOOLCHAIN_NODE;
    const out = normalizeNodeTestArgs(toks.slice(1));
    args = out.args;
    optionReorder = out.reordered;
  } else if (toks[0] === 'node') {
    form = 'node-script';
    executable = NODE_BIN;
    toolchainRow = TOOLCHAIN_NODE;
    args = rewritePackageGraphChecker(toks.slice(1));
  } else {
    throw new Error(`PLAN_COMMAND_FORM_UNSUPPORTED leaf ${leafID}: ${run}`);
  }

  return {
    leafID,
    executable,
    toolchainRow,
    args,
    timeoutMs: leafTimeoutMs(form, task.phase),
    form,
    stage,
    optionReorder,
    declaredPaths: extractDeclaredPaths(args, form),
  };
}

// ---------------------------------------------------------------------------
// Failure-class derivation (Red records only)
// ---------------------------------------------------------------------------

function deriveFailureClass(task, leaves) {
  const forms = leaves.map((l) => l.form);
  if (forms.includes('swift-package')) return 'package-graph';
  if (leaves.some((l) => l.args.some((a) => a.includes('assert-package-graph')))) return 'package-graph';
  if (leaves.some((l) => l.args.some((a) => a.includes('verify-provenance')))) return 'provenance';
  if (forms.includes('node-test')) return task.phase === '09' ? 'qualification' : 'structural';
  if (forms.includes('swift-test')) return 'behavioral';
  return null;
}

// ---------------------------------------------------------------------------
// Command policy + topology builders
// ---------------------------------------------------------------------------

function buildCommandPolicy({ stage, row, timeoutMs, leaves, task }) {
  const policy = {
    networkMode: 'forbidden',
    timeoutMs,
    stage,
    expectedExit: row.expectedExit,
    expectedOutputIncludes: Array.isArray(row.expectedOutputIncludes) ? [...row.expectedOutputIncludes] : [],
  };
  if (stage === 'red') policy.failureClass = deriveFailureClass(task, leaves);
  return policy;
}

function commandRecord({ id, kind, leaves, policy, pipefail }) {
  const rec = {
    commandID: id,
    kind,
    networkMode: policy.networkMode,
    timeoutMs: policy.timeoutMs,
    stage: policy.stage,
    expectedExit: policy.expectedExit,
    expectedOutputIncludes: policy.expectedOutputIncludes,
    leaves,
  };
  if (policy.failureClass !== undefined) rec.failureClass = policy.failureClass;
  if (pipefail !== undefined) rec.pipefail = pipefail;
  return rec;
}

function processCommand({ id, leaf, policy }) {
  return commandRecord({ id, kind: 'process', leaves: [leaf], policy });
}

function allSuccessCommand({ id, leaves, policy }) {
  return commandRecord({ id, kind: 'all-success', leaves, policy });
}

function pipelineCommand({ id, leaves, policy, pipefail }) {
  return commandRecord({ id, kind: 'pipeline', leaves, policy, pipefail: pipefail === true });
}

// ---------------------------------------------------------------------------
// convertG5Command — public entry point
// ---------------------------------------------------------------------------

/**
 * Convert one G5-R Red/Green row into a structured CommandSpec.
 * @param {{task:object, stage:'red'|'green', index:number, row:object}} input
 * @returns {object}
 */
export function convertG5Command({ task, stage, index, row }) {
  const id = `${task.id}.${stage === 'red' ? 'RED' : 'GREEN'}.${String(index + 1).padStart(3, '0')}`;
  const parsed = parseObservedG5Command(row.run);
  const leaves = parsed.leaves.map((run, leafIndex) => convertLeaf({ parentID: id, leafIndex, task, run }));
  const timeoutMs = task.phase === '09' ? 1_800_000
    : leaves.some((leaf) => leaf.form === 'swift-test' || leaf.form === 'swift-package') ? 600_000
    : 120_000;
  const policy = buildCommandPolicy({ id, stage, row, timeoutMs, leaves, task });
  if (parsed.topology === 'process') return processCommand({ id, leaf: leaves[0], policy });
  if (parsed.topology === 'all-success') return allSuccessCommand({ id, leaves, policy });
  if (parsed.topology === 'pipeline') return pipelineCommand({ id, leaves, policy, pipefail: true });
  throw new Error(`PLAN_COMMAND_FORM_UNSUPPORTED ${task.id} ${stage}`);
}

// ---------------------------------------------------------------------------
// auditCommandSpec — reject forbidden shell and malformed structure
// ---------------------------------------------------------------------------

/**
 * Audit a converted CommandSpec. Returns a deterministically sorted Finding[].
 * Never throws for data errors; malformed input yields findings.
 * @param {unknown} command
 * @returns {ReturnType<typeof makeFinding>[]}
 */
export function auditCommandSpec(command) {
  const findings = [];
  const push = (id, msg) => findings.push(makeFinding({
    id, category: 'structure', taskID: null, path: '', message: msg,
  }));

  if (!isObj(command)) {
    push('PLAN_COMMAND_SHAPE', 'command must be a CommandSpec object');
    return sortFindings(findings);
  }
  const cid = typeof command.commandID === 'string' ? command.commandID : null;

  if (!COMMAND_KINDS.includes(command.kind)) {
    push('PLAN_COMMAND_SHAPE', `kind must be one of ${COMMAND_KINDS.join('|')}, got ${String(command.kind)}`);
  }
  if (command.networkMode !== 'forbidden') {
    push('PLAN_COMMAND_SHAPE', `verification-command networkMode must be forbidden, got ${String(command.networkMode)}`);
  }
  if (!isPosInt(command.timeoutMs)) {
    push('PLAN_COMMAND_SHAPE', 'timeoutMs must be a positive integer');
  }

  const leaves = Array.isArray(command.leaves) ? command.leaves : [];
  if (command.kind === 'process' && leaves.length !== 1) {
    push('PLAN_COMMAND_SHAPE', `process command must have exactly one leaf, got ${leaves.length}`);
  }
  if ((command.kind === 'all-success' || command.kind === 'pipeline') && leaves.length < 2) {
    push('PLAN_COMMAND_SHAPE', `${command.kind} command must have at least two leaves, got ${leaves.length}`);
  }
  if (command.kind === 'pipeline' && command.pipefail !== true) {
    push('PLAN_COMMAND_SHAPE', 'pipeline command must carry pipefail: true');
  }
  if (command.kind !== 'pipeline' && command.pipefail !== undefined) {
    push('PLAN_COMMAND_SHAPE', 'only pipeline commands may carry pipefail');
  }

  // all-success / pipeline short-circuit order: leafIDs must be strictly ascending.
  if (command.kind === 'all-success' || command.kind === 'pipeline') {
    for (let i = 1; i < leaves.length; i++) {
      const a = leaves[i - 1] && leaves[i - 1].leafID;
      const b = leaves[i] && leaves[i].leafID;
      if (typeof a !== 'string' || typeof b !== 'string' || !(b > a)) {
        push('PLAN_COMMAND_SHAPE', `${command.kind} leafIDs must be ascending at index ${i}`);
        break;
      }
    }
  }

  for (let i = 0; i < leaves.length; i++) {
    const leaf = leaves[i];
    const where = `leaf ${i}`;
    if (!isObj(leaf)) { push('PLAN_COMMAND_SHAPE', `${where} must be a ProcessSpec object`); continue; }
    if (!VALID_EXECUTABLES.has(leaf.executable)) {
      push('PLAN_COMMAND_SHAPE', `${where} executable ${String(leaf.executable)} is not a pinned toolchain path`);
    }
    if (!isPosInt(leaf.timeoutMs)) {
      push('PLAN_COMMAND_SHAPE', `${where} timeoutMs must be a positive integer`);
    }
    if (!Array.isArray(leaf.args) || !leaf.args.every((a) => typeof a === 'string')) {
      push('PLAN_COMMAND_SHAPE', `${where} args must be a string array`);
      continue;
    }
    for (const a of leaf.args) {
      if (COMPOSITION_TOKENS.includes(a)) {
        push('PLAN_COMMAND_FORBIDDEN_SHELL', `${where} arg "${a}" is a composition operator`);
      }
      if (SUBSTITUTION_RE.test(a)) {
        push('PLAN_COMMAND_FORBIDDEN_SHELL', `${where} arg "${a}" uses command substitution`);
      }
      if (GLOB_RE.test(a)) {
        push('PLAN_COMMAND_FORBIDDEN_SHELL', `${where} arg "${a}" is an implicit glob`);
      }
      if (INTERACTIVE_FLAGS.has(a)) {
        push('PLAN_COMMAND_FORBIDDEN_SHELL', `${where} arg "${a}" is an interactive flag`);
      }
    }
    if (leaf.form === 'node-test') {
      const ti = leaf.args.indexOf('--test');
      const pi = leaf.args.indexOf('--test-name-pattern');
      if (ti === 0 && pi > 0 && leaf.args[1] !== '--test-name-pattern') {
        push('PLAN_COMMAND_NODE_OPTION', `${where} node-test --test-name-pattern must precede the file`);
      }
    }
  }

  if (command.stage === 'red') {
    if (!FAILURE_CLASSES.includes(command.failureClass)) {
      push('PLAN_COMMAND_FAILURE_CLASS', `Red failureClass ${String(command.failureClass)} is outside the closed set`);
    }
    if (!Array.isArray(command.expectedOutputIncludes) || command.expectedOutputIncludes.length === 0) {
      push('PLAN_COMMAND_MARKER_ABSENT', 'Red record must retain its G5 required output marker');
    }
  }

  // stamp the taskID onto findings for traceability
  for (const f of findings) f.taskID = cid;
  return sortFindings(findings);
}

// ---------------------------------------------------------------------------
// summarizeConversion — the exact pinned summary line
// ---------------------------------------------------------------------------

/**
 * Produce the conversion summary line. Counts records by topology, leaves by
 * form, and the Node-test option reorders.
 * @param {object[]} records
 * @returns {string}
 */
export function summarizeConversion(records) {
  let process = 0, allSuccess = 0, pipeline = 0, leaves = 0;
  let swiftTest = 0, nodeTest = 0, nodeScript = 0, swiftPackage = 0;
  let nodeOptionReorders = 0, unsupported = 0;
  for (const r of records) {
    if (r.kind === 'process') process++;
    else if (r.kind === 'all-success') allSuccess++;
    else if (r.kind === 'pipeline') pipeline++;
    else unsupported++;
    for (const l of r.leaves) {
      leaves++;
      if (l.form === 'swift-test') swiftTest++;
      else if (l.form === 'node-test') nodeTest++;
      else if (l.form === 'node-script') nodeScript++;
      else if (l.form === 'swift-package') swiftPackage++;
      else unsupported++;
      if (l.optionReorder) nodeOptionReorders++;
    }
  }
  return `records=${records.length} process=${process} allSuccess=${allSuccess} pipeline=${pipeline} leaves=${leaves} swiftTest=${swiftTest} nodeTest=${nodeTest} nodeScript=${nodeScript} swiftPackage=${swiftPackage} nodeOptionReorders=${nodeOptionReorders} unsupported=${unsupported}`;
}
