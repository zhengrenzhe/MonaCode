#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { auditFixture, auditPlan } from './lib/audit.mjs';
import { buildContractInventory } from './lib/inventory.mjs';

const planDirectory = path.dirname(fileURLToPath(import.meta.url));
const contractDirectory = path.dirname(planDirectory);
const artifactDirectory = path.join(contractDirectory, 'artifacts');

const loadJSON = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const contract = loadJSON(path.join(artifactDirectory, 'monacode-g5r-authoritative-manifest.json'));
const plan = loadJSON(path.join(artifactDirectory, 'monacode-g5r-implementation-plan-manifest.json'));
const inventory = buildContractInventory(artifactDirectory);

function usageFailure(message) {
  const result = {
    status: 'error',
    findingCount: 1,
    findings: [{ id: 'PLAN_CLI_USAGE', subject: 'arguments', message }]
  };
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.stderr.write(`PLAN_CLI_USAGE\targuments\t${message}\n`);
  process.exitCode = 2;
}

function parseArguments(args) {
  if (args.length === 0) return { kind: 'plan', phase: null };
  if (args.length === 2 && args[0] === '--phase' && /^(0[0-9])$/.test(args[1])) {
    return { kind: 'plan', phase: args[1] };
  }
  if (args.length === 2 && args[0] === '--fixture') {
    return { kind: 'fixture', file: path.resolve(args[1]) };
  }
  return null;
}

const options = parseArguments(process.argv.slice(2));
if (options === null) {
  usageFailure('expected no arguments, --phase 00 through 09, or --fixture path');
} else {
  let result;
  if (options.kind === 'fixture') {
    result = auditFixture({
      fixture: loadJSON(options.file),
      contract,
      seedPlan: plan,
      inventory
    });
  } else {
    result = auditPlan({
      contract,
      plan,
      inventory,
      planDirectory: contractDirectory,
      mode: { phase: options.phase }
    });
  }
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  for (const finding of result.findings) {
    process.stderr.write(`${finding.id}\t${finding.subject}\t${finding.message}\n`);
  }
  process.exitCode = result.findingCount === 0 ? 0 : 1;
}
