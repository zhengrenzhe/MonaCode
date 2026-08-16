// Task 25: G5↔G6 frozen-scope comparator and G6-R contract candidate builder.
//
// Exports:
//   PERMITTED_PREFIXES         — the ten bytewise-sorted permitted JSON pointer prefixes
//   compareFrozenScope(g5, g6) — normalize authority arrays by id, compare every JSON leaf,
//                                 accept only the ten permitted prefixes, return forbidden findings
//   buildG6Candidate(g5, opts) — deep-clone G5, apply only the permitted deltas, return G6 manifest
//   buildHtmlCompanion(g6)     — render a non-normative HTML visualization whose values equal the manifest
//
// CLI: builds the G6 authoritative manifest + HTML companion, writes them to disk,
// compares G5 vs G6, prints `G6_SCOPE_EQUAL forbiddenDeltas=0 permittedDeltasOnly=true`.

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(here, '../..');
const G6_ARTIFACTS = resolve(REPO_ROOT, 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts');
const G5_PARENT_ROOT = resolve(G6_ARTIFACTS, 'parent/g5-r');
const G5_MANIFEST_PATH = resolve(G5_PARENT_ROOT, 'artifacts/monacode-g5r-authoritative-manifest.json');
const G6_MANIFEST_PATH = resolve(G6_ARTIFACTS, 'monacode-g6r-authoritative-manifest.json');
const G6_HTML_PATH = resolve(G6_ARTIFACTS, 'global-g6r-authoritative-contract.html');

// The ten bytewise-sorted permitted JSON pointer prefixes.
// After arrays with an `id` field are normalized to ID-keyed objects, these are the
// ONLY prefixes whose leaves may differ between G5 and G6. Every other leaf must
// be copied exactly from G5.
export const PERMITTED_PREFIXES = [
  '/authorityRules/companion',
  '/authorityRules/global',
  '/authorityRules/hashMismatch',
  '/identity/revision',
  '/identity/status',
  '/machineArtifacts/implementationPlan',
  '/parent',
  '/planGovernance',
  '/schemaVersion',
  '/verificationTools/planVerifier',
];

// ---------------------------------------------------------------------------
// Normalization: arrays of objects with an `id` field → objects keyed by id.
// ---------------------------------------------------------------------------

function normalizeById(node) {
  if (Array.isArray(node)) {
    if (node.length > 0 && node.every((el) => el && typeof el === 'object' && !Array.isArray(el) && 'id' in el)) {
      const obj = {};
      for (const el of node) {
        obj[String(el.id)] = normalizeById(el);
      }
      return obj;
    }
    return node.map((el) => normalizeById(el));
  }
  if (node !== null && typeof node === 'object') {
    const obj = {};
    for (const key of Object.keys(node)) {
      obj[key] = normalizeById(node[key]);
    }
    return obj;
  }
  return node;
}

// ---------------------------------------------------------------------------
// Leaf collection: walk the normalized tree and record every primitive leaf
// with its JSON Pointer (RFC 6901).
// ---------------------------------------------------------------------------

function escapeToken(key) {
  return String(key).replace(/~/g, '~0').replace(/\//g, '~1');
}

function collectLeaves(node, basePath, leaves) {
  if (node === null) {
    leaves.set(basePath, null);
    return;
  }
  const t = typeof node;
  if (t === 'object') {
    if (Array.isArray(node)) {
      for (let i = 0; i < node.length; i++) {
        collectLeaves(node[i], `${basePath}/${i}`, leaves);
      }
    } else {
      for (const key of Object.keys(node)) {
        collectLeaves(node[key], `${basePath}/${escapeToken(key)}`, leaves);
      }
    }
    return;
  }
  // primitive: string, number, boolean
  leaves.set(basePath, node);
}

// ---------------------------------------------------------------------------
// Permitted-prefix check.
// ---------------------------------------------------------------------------

function isPermitted(pointer) {
  for (const prefix of PERMITTED_PREFIXES) {
    if (pointer === prefix) return true;
    if (pointer.startsWith(prefix + '/')) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// compareFrozenScope(g5, g6): normalize both by id, collect every leaf from
// both trees, compare values, and return one finding per forbidden delta.
// Permitted-prefix deltas produce no finding.
// ---------------------------------------------------------------------------

export function compareFrozenScope(g5, g6) {
  const n5 = normalizeById(g5);
  const n6 = normalizeById(g6);
  const leaves5 = new Map();
  const leaves6 = new Map();
  collectLeaves(n5, '', leaves5);
  collectLeaves(n6, '', leaves6);

  const allPointers = new Set([...leaves5.keys(), ...leaves6.keys()]);
  const findings = [];
  for (const ptr of allPointers) {
    const v5 = leaves5.get(ptr);
    const v6 = leaves6.get(ptr);
    const has5 = leaves5.has(ptr);
    const has6 = leaves6.has(ptr);
    if (has5 && has6) {
      if (!deepEqual(v5, v6)) {
        if (!isPermitted(ptr)) {
          findings.push({ id: 'G6_FORBIDDEN_SCOPE_DELTA', pointer: ptr, g5Value: v5, g6Value: v6 });
        }
      }
    } else {
      // added or removed leaf
      if (!isPermitted(ptr)) {
        findings.push({
          id: 'G6_FORBIDDEN_SCOPE_DELTA',
          pointer: ptr,
          g5Value: has5 ? v5 : undefined,
          g6Value: has6 ? v6 : undefined,
        });
      }
    }
  }
  findings.sort((a, b) => (a.pointer < b.pointer ? -1 : a.pointer > b.pointer ? 1 : 0));
  return findings;
}

function deepEqual(a, b) {
  if (a === b) return true;
  if (a === null || b === null) return a === b;
  if (typeof a !== typeof b) return false;
  return JSON.stringify(a) === JSON.stringify(b);
}

// ---------------------------------------------------------------------------
// buildG6Candidate(g5, opts): deep-clone G5 and apply only the ten permitted
// deltas. Every non-permitted G5 JSON value is copied exactly.
// ---------------------------------------------------------------------------

function sha256File(filePath) {
  return createHash('sha256').update(readFileSync(filePath)).digest('hex');
}

export function buildG6Candidate(g5, opts = {}) {
  const root = opts.repoRoot || REPO_ROOT;
  const artifactsDir = resolve(root, 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts');

  // G6 plan hashes (computed from the real Task-24 artifacts on disk).
  const schemaFile = 'monacode-g6r-execution-schema.json';
  const planFile = 'monacode-g6r-implementation-plan-manifest.json';
  const cmdDepFile = 'monacode-g6r-command-dependency-manifest.json';
  const ifaceFile = 'monacode-g6r-interface-contract-manifest.json';
  const schemaSha = sha256File(resolve(artifactsDir, schemaFile));
  const planSha = sha256File(resolve(artifactsDir, planFile));
  const cmdDepSha = sha256File(resolve(artifactsDir, cmdDepFile));
  const ifaceSha = sha256File(resolve(artifactsDir, ifaceFile));

  // Source-acquisition count from the assembled G6 plan manifest.
  const planManifest = JSON.parse(readFileSync(resolve(artifactsDir, planFile), 'utf8'));
  const sourceAcquisitionCount = planManifest.sourceAcquisitions.length;

  // Deep clone G5 — every non-permitted leaf is preserved exactly.
  const g6 = JSON.parse(JSON.stringify(g5));

  // 1. /schemaVersion
  g6.schemaVersion = 3;

  // 2-3. /identity/revision, /identity/status
  g6.identity.revision = 'G6-R-execution-ready-candidate';
  g6.identity.status = 'design-and-execution-plan-candidate';

  // 4-6. /authorityRules/{global,companion,hashMismatch}
  g6.authorityRules.global =
    'This G6-R JSON manifest is the sole global authority and replaces G1-R through G5-R. Historical artifacts remain evidence and are not edited into apparent validity.';
  g6.authorityRules.companion =
    'global-g6r-authoritative-contract.html is a non-normative visualization of this manifest; any difference is resolved in favor of the hash-verified JSON manifest.';
  g6.authorityRules.hashMismatch =
    'a missing local normative file or SHA-256 mismatch invalidates G6 and blocks execution';

  // 7. /parent — the embedded G5-R snapshot this candidate inherits.
  g6.parent = {
    root: 'artifacts/parent/g5-r',
    revision: 'G5-R-full-scope-final',
    files: 148,
    bytes: 4050132,
    checksumRows: 144,
    checksumIndexSha256:
      'b8546da4a43056ca4b0f944ac33c872d0d12fa14fe29e5e296b0eedb10423e8f',
    adoptionRecordSha256:
      '9f2e0e8be14940050bc2d649f2c27cc3237379f31617e019d5f7389943b6513c',
    authoritativeManifestSha256:
      'b8f9b31f739d2b5587b3bef1699786cef465af3f7173a1c413d276772c81f94f',
    implementationPlanSha256:
      '114979c5faf1369d1f74a8a3905981c1cbef85b9dd93b6a12f8fc48460e64b5c',
  };

  // 8. /planGovernance — the G6-R execution-readiness governance block.
  g6.planGovernance = {
    planState: 'execution-ready-candidate',
    adoptionState: 'candidate',
    implementation: 'not-started',
    releaseAcceptance: 'not-passed',
    taskTestContracts: 200,
    verificationCommands: 400,
    leaves: 407,
    beginActions: 200,
    commitActions: 200,
    finalizeActions: 200,
    productCommitContracts: 200,
    evidenceCommitContracts: 200,
    productCommitSubjectTemplate: 'monacode: complete <TASK_ID>',
    evidenceCommitSubjectTemplate: 'evidence(monacode): complete <TASK_ID>',
    evidenceCommitSelectorMode: 'external-git',
    workspaceLifecycle: 'token-bound',
    sourceAcquisitions: {
      count: sourceAcquisitionCount,
      sourceGaps: 0,
      acquisitionGaps: 0,
    },
    planningArtifactPaths: {
      implementationPlanManifest: planFile,
      commandDependencyManifest: cmdDepFile,
      interfaceContractManifest: ifaceFile,
      executionSchema: schemaFile,
    },
    authoringTaskProducers: {
      audit: 'Task 26',
      adversarialReview: 'Tasks 29-32',
      coldCheckoutEvidence: 'Task 28',
    },
  };

  // 9. /machineArtifacts/implementationPlan — replace with G6 paths and hashes.
  const implRow = g6.machineArtifacts.find((m) => m.id === 'implementationPlan');
  if (implRow) {
    Object.keys(implRow).forEach((k) => delete implRow[k]);
    Object.assign(implRow, {
      id: 'implementationPlan',
      schemaFile,
      schemaSha256: schemaSha,
      planFile,
      planSha256: planSha,
      commandDependencyFile: cmdDepFile,
      commandDependencySha256: cmdDepSha,
      interfaceContractFile: ifaceFile,
      interfaceContractSha256: ifaceSha,
      planAuditFile: '../implementation-plan/verification/plan-audit.json',
      planAuditAvailability: 'declared-by-plan',
      planAuditProducer: 'Task 27',
      adversarialReviewFile: '../implementation-plan/verification/adversarial-plan-review.md',
      adversarialReviewAvailability: 'declared-by-plan',
      adversarialReviewProducer: 'Tasks 29-32',
      adoptionState: 'candidate',
    });
  }

  // 10. /verificationTools/planVerifier — replace with Task 26 destination.
  const verRow = g6.verificationTools.find((v) => v.id === 'planVerifier');
  if (verRow) {
    Object.keys(verRow).forEach((k) => delete verRow[k]);
    Object.assign(verRow, {
      id: 'planVerifier',
      file: '../implementation-plan/runtime/planctl.mjs',
      availability: 'declared-by-plan',
      producer: 'Task 26',
      use: 'schema, graph, Markdown equivalence, ownership, boundary, evidence, environment and negative-fixture audit',
    });
  }

  return g6;
}

// ---------------------------------------------------------------------------
// buildHtmlCompanion(g6): render a non-normative HTML visualization whose
// every rendered value equals its machine source.
// ---------------------------------------------------------------------------

export function buildHtmlCompanion(g6) {
  const sc = g6.surfaceCounts;
  const env = g6.currentLocalEnvironment;
  const pg = g6.planGovernance;
  const parent = g6.parent;
  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MonaCode G6-R authoritative contract</title>
  <style>
    :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
    body { max-width: 1040px; margin: 0 auto; padding: 40px 24px 80px; line-height: 1.55; }
    h1, h2 { line-height: 1.2; }
    .candidate { border: 1px solid #b45309; border-radius: 10px; padding: 14px 16px; background: color-mix(in srgb, #b45309 12%, transparent); }
    table { width: 100%; border-collapse: collapse; }
    th, td { border-bottom: 1px solid #8886; padding: 8px; text-align: left; vertical-align: top; }
    code { font-family: ui-monospace, SFMono-Regular, monospace; }
  </style>
</head>
<body>
  <h1>MonaCode G6-R authoritative contract</h1>
  <p class="candidate"><strong>Status:</strong> ${g6.identity.status}. Revision <code>${g6.identity.revision}</code>. The design scope is frozen and the complete execution plan is assembled; product implementation has not started and release acceptance has not passed.</p>

  <h2>Authority</h2>
  <ol>
    <li>The embedded <code>artifacts/parent/g5-r/adoption-record.json</code> selects the exact adopted G5-R bytes.</li>
    <li><code>monacode-g6r-authoritative-manifest.json</code> is the normative product and acceptance contract.</li>
    <li><code>monacode-g6r-implementation-plan-manifest.json</code> is the normative 200-task, 400-command, 407-leaf execution graph.</li>
    <li><code>global-g6r-authoritative-contract.html</code> is the non-normative companion to this manifest; any difference is resolved in favor of the hash-verified JSON manifest.</li>
    <li>This HTML file is explanatory and never overrides either machine manifest.</li>
  </ol>

  <h2>Inherited parent snapshot</h2>
  <table>
    <tr><th>Parent root</th><td><code>${parent.root}</code></td></tr>
    <tr><th>Parent revision</th><td>${parent.revision}</td></tr>
    <tr><th>Files</th><td>${parent.files}</td></tr>
    <tr><th>Bytes</th><td>${parent.bytes.toLocaleString('en-US')}</td></tr>
    <tr><th>Checksum rows</th><td>${parent.checksumRows}</td></tr>
    <tr><th>Checksum index SHA-256</th><td><code>${parent.checksumIndexSha256}</code></td></tr>
    <tr><th>Adoption record SHA-256</th><td><code>${parent.adoptionRecordSha256}</code></td></tr>
    <tr><th>Authoritative manifest SHA-256</th><td><code>${parent.authoritativeManifestSha256}</code></td></tr>
    <tr><th>Implementation plan SHA-256</th><td><code>${parent.implementationPlanSha256}</code></td></tr>
  </table>
  <p>Every unchanged inherited <code>file</code>, <code>path</code>, or schema reference resolves relative to that embedded parent root; only G6 planning-governance rows resolve relative to the G6 archive root.</p>

  <h2>Frozen product scope (inherited from G5-R)</h2>
  <table>
    <tr><th>Baseline</th><td><code>${g6.identity.behaviorBaseline}</code></td></tr>
    <tr><th>Public declarations</th><td>${sc.publicDeclarations.total} total: ${sc.publicDeclarations.retained} retained, ${sc.publicDeclarations.cut} cut</td></tr>
    <tr><th>Features</th><td>${sc.features.baseline} total: ${sc.features.retainedMacOS} retained for macOS, one later iPadOS entry, one WebGPU debug cut</td></tr>
    <tr><th>Language infrastructure</th><td>${sc.languageInfrastructure.surfaces} provider surfaces; LSP 3.18 client architecture; zero bundled language implementations, grammar packs, snippet catalogs, or LSP servers</td></tr>
    <tr><th>Acceptance</th><td>${g6.acceptance.correctnessGates[0]}-${g6.acceptance.correctnessGates[g6.acceptance.correctnessGates.length - 1]}, P00-P13, M0/M1, 60/120 Hz, and <code>native/comparator &lt;= 1.00</code> remain unchanged</td></tr>
    <tr><th>Release target</th><td>${g6.identity.currentRelease} only; iOS and iPadOS are outside this release verdict</td></tr>
  </table>

  <h2>Architecture retained from G4-R</h2>
  <ul>
    <li>Raw UTF-16 Piece Tree model truth and MainActor live ownership.</li>
    <li>Core Text shaping, layout, geometry, and hit testing.</li>
    <li>A complete Core Graphics renderer first; Metal exists only if the Phase 03 renderer-owned gate fails, and parity closes before later phases.</li>
    <li>Custom AppKit input, transfer, accessibility, and embedding; SwiftUI owns lifecycle wrappers only.</li>
    <li>Foundation-only <code>MonaCode</code>, AppKit/Core Text/Core Graphics/conditional Metal in <code>MonaCodeAppKit</code>, and explicit dependencies for <code>MonaCodeSwiftUI</code>.</li>
  </ul>

  <h2>Qualified environment (inherited from G5-R)</h2>
  <table>
    <tr><th>macOS</th><td>${env.macOS} build <code>${env.macOSBuild}</code></td></tr>
    <tr><th>Xcode / SDK / Swift</th><td>${env.xcode} build <code>${env.xcodeBuild}</code> / SDK ${env.sdk} / Swift ${env.swift}</td></tr>
    <tr><th>Hardware class</th><td>${env.architecture} ${env.machineClass}, ${env.soc}, ${env.gpuCores} GPU cores, ${env.memoryGiB} GiB, ${env.metalSupport}</td></tr>
    <tr><th>Built-in display</th><td>3456 x 2234 pixels, 1728 x 1117 logical points, 2x, 120 Hz</td></tr>
    <tr><th>Chrome</th><td>${env.chrome}; V8 ${env.v8}; Chromium ICU ${env.chromeIcu}</td></tr>
  </table>
  <p>The dated ${env.observedDate} observation contains one privacy-filtered, unqualified LG external-display slot. Every formal C/P run requires <code>externalDisplayCount == 0</code>. External-display behavior is excluded from the release verdict.</p>

  <h2>Plan governance added by G6-R</h2>
  <table>
    <tr><th>Plan state</th><td>${pg.planState}</td></tr>
    <tr><th>Adoption state</th><td>${pg.adoptionState}</td></tr>
    <tr><th>Implementation</th><td>${pg.implementation}</td></tr>
    <tr><th>Release acceptance</th><td>${pg.releaseAcceptance}</td></tr>
    <tr><th>Task-test contracts</th><td>${pg.taskTestContracts}</td></tr>
    <tr><th>Verification commands</th><td>${pg.verificationCommands}</td></tr>
    <tr><th>Leaves</th><td>${pg.leaves}</td></tr>
    <tr><th>Begin / commit / finalize actions</th><td>${pg.beginActions} / ${pg.commitActions} / ${pg.finalizeActions}</td></tr>
    <tr><th>Product-commit contracts</th><td>${pg.productCommitContracts}</td></tr>
    <tr><th>Evidence-commit contracts</th><td>${pg.evidenceCommitContracts}</td></tr>
    <tr><th>Product-commit subject template</th><td><code>${pg.productCommitSubjectTemplate}</code></td></tr>
    <tr><th>Evidence-commit subject template</th><td><code>${pg.evidenceCommitSubjectTemplate}</code></td></tr>
    <tr><th>Evidence-commit selector mode</th><td>${pg.evidenceCommitSelectorMode}</td></tr>
    <tr><th>Workspace lifecycle</th><td>${pg.workspaceLifecycle}</td></tr>
    <tr><th>Source acquisitions</th><td>${pg.sourceAcquisitions.count} (sourceGaps=${pg.sourceAcquisitions.sourceGaps}, acquisitionGaps=${pg.sourceAcquisitions.acquisitionGaps})</td></tr>
    <tr><th>Implementation plan manifest</th><td><code>${pg.planningArtifactPaths.implementationPlanManifest}</code></td></tr>
    <tr><th>Command dependency manifest</th><td><code>${pg.planningArtifactPaths.commandDependencyManifest}</code></td></tr>
    <tr><th>Interface contract manifest</th><td><code>${pg.planningArtifactPaths.interfaceContractManifest}</code></td></tr>
    <tr><th>Execution schema</th><td><code>${pg.planningArtifactPaths.executionSchema}</code></td></tr>
    <tr><th>Audit producer</th><td>${pg.authoringTaskProducers.audit}</td></tr>
    <tr><th>Adversarial review producer</th><td>${pg.authoringTaskProducers.adversarialReview}</td></tr>
    <tr><th>Cold-checkout evidence producer</th><td>${pg.authoringTaskProducers.coldCheckoutEvidence}</td></tr>
  </table>
  <p>The plan verifier at <code>../implementation-plan/runtime/planctl.mjs</code> is declared by plan (availability <code>declared-by-plan</code>, producer <code>${pg.authoringTaskProducers.audit}</code>); Task 33 requires the final file hash.</p>

  <h2>Empirical boundary</h2>
  <p>This revision creates documentation, machine contracts, verification tools, and the complete product execution plan only. It creates no product Swift source, generated product table, release package, C01-C10 result, or P00-P13 result.</p>
</body>
</html>
`;
  return html;
}

// ---------------------------------------------------------------------------
// CLI: build the G6 authoritative manifest + HTML companion, compare G5 vs G6,
// and print the result line.
// ---------------------------------------------------------------------------

function writeManifest(path, obj) {
  writeFileSync(path, JSON.stringify(obj, null, 2) + '\n');
}

function main() {
  const g5 = JSON.parse(readFileSync(G5_MANIFEST_PATH, 'utf8'));

  // Build the G6 candidate (copying every non-permitted G5 value exactly).
  const g6Expected = buildG6Candidate(g5, { repoRoot: REPO_ROOT });

  // Write the G6 authoritative manifest.
  writeManifest(G6_MANIFEST_PATH, g6Expected);

  // Write the HTML companion.
  writeFileSync(G6_HTML_PATH, buildHtmlCompanion(g6Expected));

  // Load the written manifest (round-trip) and compare.
  const g6Committed = JSON.parse(readFileSync(G6_MANIFEST_PATH, 'utf8'));
  const findings = compareFrozenScope(g5, g6Committed);

  // Also verify canonical encoding of the non-permitted portion matches.
  const canonicalMatch = canonicalNonPermittedEqual(g5, g6Committed);

  const forbidden = findings.length;
  const permittedDeltasOnly = forbidden === 0 && canonicalMatch;

  if (forbidden === 0 && permittedDeltasOnly) {
    process.stdout.write(
      `G6_SCOPE_EQUAL forbiddenDeltas=0 permittedDeltasOnly=true\n`,
    );
  } else {
    process.stdout.write(
      `G6_FORBIDDEN_SCOPE_DELTA forbiddenDeltas=${forbidden} permittedDeltasOnly=${permittedDeltasOnly}\n`,
    );
    for (const f of findings) {
      process.stdout.write(`  ${f.pointer} g5=${JSON.stringify(f.g5Value)} g6=${JSON.stringify(f.g6Value)}\n`);
    }
    process.exitCode = 1;
  }
}

// canonicalNonPermittedEqual: strip all permitted-prefix leaves from both
// manifests, canonicalize (sorted keys), and compare. This verifies that the
// non-permitted portion of G6 is byte-identical to G5.
function canonicalNonPermittedEqual(g5, g6) {
  const n5 = normalizeById(g5);
  const n6 = normalizeById(g6);
  const stripped5 = stripPermitted(n5, '');
  const stripped6 = stripPermitted(n6, '');
  return canonicalJson(stripped5) === canonicalJson(stripped6);
}

function stripPermitted(node, path) {
  if (node === null) return null;
  if (Array.isArray(node)) {
    return node.map((el, i) => stripPermitted(el, `${path}/${i}`));
  }
  if (typeof node === 'object') {
    const obj = {};
    for (const key of Object.keys(node)) {
      const childPath = `${path}/${escapeToken(key)}`;
      if (isPermitted(childPath)) continue; // strip permitted leaves
      obj[key] = stripPermitted(node[key], childPath);
    }
    return obj;
  }
  return node;
}

function canonicalJson(node) {
  if (node === null) return 'null';
  if (Array.isArray(node)) {
    return '[' + node.map(canonicalJson).join(',') + ']';
  }
  if (typeof node === 'object') {
    const keys = Object.keys(node).sort();
    return '{' + keys.map((k) => JSON.stringify(k) + ':' + canonicalJson(node[k])).join(',') + '}';
  }
  return JSON.stringify(node);
}

// Run CLI when executed directly.
const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  main();
}
