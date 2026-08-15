// G6-R non-interactive plan execution controller.
//
// planctl.mjs provides the single non-interactive entry point for plan
// verification and execution. Every command writes canonical JSON to stdout and
// findings to the same payload; exit 0 means zero findings.
//
// createPlanctl({ handlers }) is the dependency-injection factory used by tests:
// handlers is a Map<name, async ({ command, flags }) => { result, findings }>).
// The CLI entry point uses pre-assembly handlers that return the exact finding
// PLAN_AUTHORITY_NOT_ASSEMBLED until Task 26 replaces them with the complete
// audit/runtime handlers. Dispatch and argument tests assert this result
// instead of claiming an assembled plan exists.

import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { makeFinding, sortFindings } from '../lib/findings.mjs';
import { canonicalJSONStringify } from '../lib/canonical-json.mjs';

export const PLAN_AUTHORITY_NOT_ASSEMBLED = 'PLAN_AUTHORITY_NOT_ASSEMBLED';

// ---------------------------------------------------------------------------
// Closed command table.
// ---------------------------------------------------------------------------

// Each command's closed flag set (every flag takes a value). Multi-word command
// keys are listed verbatim. Flags are required to appear exactly once.
const COMMAND_FLAGS = {
  'verify-archive': [],
  'audit': [],
  'simulate': [],
  'render': [],
  'begin-task': ['--task', '--evidence-path'],
  'resume-task': ['--task', '--evidence-path'],
  'preflight --all': [],
  'preflight --task': ['--task'],
  'run-command': ['--id', '--evidence-path'],
  'acquire-source': ['--task', '--source', '--evidence-path'],
  'commit-task': ['--task', '--evidence-path'],
  'finalize-evidence': ['--task', '--path'],
  'interfaces compile': [],
  'next': ['--evidence-root'],
  'verify-evidence': ['--task', '--path'],
};

const ALL_FLAGS = new Set();
for (const flags of Object.values(COMMAND_FLAGS)) for (const f of flags) ALL_FLAGS.add(f);

// ---------------------------------------------------------------------------
// Argument parsing.
// ---------------------------------------------------------------------------

function dispatchFinding(message) {
  return makeFinding({ id: 'PLAN_COMMAND_DISPATCH', category: 'structure', taskID: null, path: '', message });
}

/**
 * Parse an argv array into a command key + flags map. Returns
 * { command, flags, findings } where findings carries any parse error (unknown
 * command, unknown flag, duplicate flag, missing required flag).
 * @param {string[]} argv
 */
function parseArgv(argv) {
  const findings = [];
  const args = Array.isArray(argv) ? argv : [];

  // Resolve the command key.
  let command = null;
  let rest = [];

  if (args.length === 0) {
    findings.push(dispatchFinding('no command given'));
    return { command: null, flags: {}, findings };
  }

  const first = args[0];
  if (first === 'interfaces' && args[1] === 'compile') {
    command = 'interfaces compile';
    rest = args.slice(2);
  } else if (first === 'preflight') {
    if (args[1] === '--all') {
      command = 'preflight --all';
      rest = args.slice(2);
    } else if (args[1] === '--task') {
      command = 'preflight --task';
      rest = args.slice(1);
    } else {
      findings.push(dispatchFinding('preflight requires --all or --task'));
      return { command: null, flags: {}, findings };
    }
  } else if (first in COMMAND_FLAGS) {
    command = first;
    rest = args.slice(1);
  } else {
    findings.push(dispatchFinding(`unknown command: ${first}`));
    return { command: null, flags: {}, findings };
  }

  // Parse --flag value pairs.
  const flags = {};
  const allowedFlags = COMMAND_FLAGS[command];
  for (let i = 0; i < rest.length; i++) {
    const tok = rest[i];
    if (!tok.startsWith('--') || tok.length <= 2) {
      findings.push(dispatchFinding(`unexpected positional token: ${tok}`));
      continue;
    }
    if (!ALL_FLAGS.has(tok)) {
      findings.push(dispatchFinding(`unknown flag: ${tok}`));
      // Skip its value if present.
      if (rest[i + 1] && !rest[i + 1].startsWith('--')) i++;
      continue;
    }
    if (!allowedFlags.includes(tok)) {
      findings.push(dispatchFinding(`flag ${tok} is not valid for command ${command}`));
      if (rest[i + 1] && !rest[i + 1].startsWith('--')) i++;
      continue;
    }
    if (tok in flags) {
      findings.push(dispatchFinding(`duplicate flag: ${tok}`));
      if (rest[i + 1] && !rest[i + 1].startsWith('--')) i++;
      continue;
    }
    const value = rest[i + 1];
    if (value === undefined || value.startsWith('--')) {
      findings.push(dispatchFinding(`flag ${tok} requires a value`));
      continue;
    }
    flags[tok] = value;
    i++;
  }

  // Required flags present.
  for (const f of allowedFlags) {
    if (!(f in flags)) {
      findings.push(dispatchFinding(`missing required flag ${f} for command ${command}`));
    }
  }

  return { command, flags, findings: sortFindings(findings) };
}

// ---------------------------------------------------------------------------
// createPlanctl — dependency-injection factory.
// ---------------------------------------------------------------------------

/**
 * Build a planctl controller with injected handlers.
 * @param {{ handlers: Map<string, Function> }} opts
 * @returns {{ run(argv: string[]): Promise<{ command: string|null, result: unknown, findings: object[], stdout: string, exitCode: number }> }}
 */
export function createPlanctl({ handlers }) {
  const handlerMap = handlers instanceof Map ? handlers : new Map(Object.entries(handlers || {}));

  return {
    async run(argv) {
      const { command, flags, findings: parseFindings } = parseArgv(argv);
      let findings = parseFindings;
      let result = null;

      if (command && findings.length === 0) {
        const handler = handlerMap.get(command);
        if (typeof handler !== 'function') {
          findings = [dispatchFinding(`no handler bound for command: ${command}`)];
        } else {
          const r = await handler({ command, flags });
          result = r.result;
          findings = sortFindings(r.findings || []);
        }
      }

      const payload = { command, result, findings };
      const stdout = canonicalJSONStringify(payload);
      const exitCode = findings.length === 0 ? 0 : 1;
      return { command, result, findings, stdout, exitCode };
    },
  };
}

// ---------------------------------------------------------------------------
// Pre-assembly handlers (return PLAN_AUTHORITY_NOT_ASSEMBLED until Task 26).
// ---------------------------------------------------------------------------

function preAssemblyHandler(commandName) {
  return async () => ({
    result: null,
    findings: [
      makeFinding({
        id: PLAN_AUTHORITY_NOT_ASSEMBLED,
        category: 'authority',
        taskID: null,
        path: '',
        message: `plan authority not assembled; complete audit/runtime handlers for ${commandName} are installed by Task 26`,
      }),
    ],
  });
}

function preAssemblyHandlers() {
  const m = new Map();
  for (const name of Object.keys(COMMAND_FLAGS)) {
    m.set(name, preAssemblyHandler(name));
  }
  return m;
}

// ---------------------------------------------------------------------------
// CLI entry point.
// ---------------------------------------------------------------------------

export async function main(argv) {
  const ctl = createPlanctl({ handlers: preAssemblyHandlers() });
  const res = await ctl.run(argv);
  process.stdout.write(res.stdout);
  process.exit(res.exitCode);
}

const __filename = fileURLToPath(import.meta.url);
if (process.argv[1] === __filename) {
  main(process.argv.slice(2));
}
