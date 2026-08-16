// G6-R contract inventory (ported from G5-R without cross-directory imports).
// Enumerates every contract identity (normative layer, machine artifact, plan
// artifact, public path, feature, registry row, provider, host group,
// correctness gate, performance workload, candidate artifact, localization
// profile) so the coverage audit can prove the plan's ownership table maps
// every retained identity exactly once and names no unknown identity.
//
// The G6-R scope is inherited from the adopted G5-R parent; the surface
// manifests live under the G6-R candidate's parent/g5-r/artifacts/ snapshot.
// The G6-R contract contributes its own normativeDomains, machineArtifacts,
// acceptance, performanceDecision, and candidateGeneratedArtifacts.

import fs from 'node:fs';
import path from 'node:path';

const INTERNAL_DIRECT_PROVIDER_IDS = [
  'MultiDocumentHighlight',
  'DocumentPasteEdit',
  'DocumentDropEdit',
];

const retainedDisposition = (disposition) => (
  !String(disposition).startsWith('cut')
  && !String(disposition).startsWith('later')
  && disposition !== 'structural-plan-governance'
);

const sortIdentities = (a, b) => (
  a.kind.localeCompare(b.kind, 'en') || a.id.localeCompare(b.id, 'en')
);

const isObj = (v) => v !== null && typeof v === 'object';

/**
 * Build the contract inventory from the G6-R artifact directory.
 * @param {string} artifactDirectory
 * @returns {{schemaVersion:number, identities:Array, retained:Array, dispositionOnly:Array, counts:Record<string,number>}}
 */
export function buildContractInventory(artifactDirectory) {
  const load = (rel) => JSON.parse(fs.readFileSync(path.join(artifactDirectory, rel), 'utf8'));
  const contract = load('monacode-g6r-authoritative-manifest.json');
  const parentArtDir = path.join('parent', 'g5-r', 'artifacts');
  const scope = load(path.join(parentArtDir, 'monaco-0.56.0-f1r3-scope-manifest.json'));
  const declarations = load(path.join(parentArtDir, 'monaco-0.56.0-f1r4-public-declaration-manifest.json'));
  const localization = load(path.join(parentArtDir, 'monacode-n1r-localization-manifest.json'));
  const host = load(path.join(parentArtDir, 'monacode-h1r2-host-group-correction-manifest.json'));

  const identities = [];
  const keys = new Set();

  const add = (kind, id, disposition = 'retained', details = {}) => {
    const stringID = String(id);
    const key = `${kind}:${stringID}`;
    if (keys.has(key)) throw new Error(`duplicate contract inventory identity: ${key}`);
    keys.add(key);
    identities.push({
      kind,
      id: stringID,
      disposition,
      retained: retainedDisposition(disposition),
      ...details,
    });
  };

  // Normative layers + machine artifacts from the G6-R contract. The
  // implementationPlan domain and machineArtifact are plan-governance surfaces
  // represented by the planArtifact rows below, so they are skipped here to
  // avoid a duplicate identity that the ownership table does not carry.
  for (const domain of contract.normativeDomains ?? []) {
    if (domain.domain === 'implementationPlan') continue;
    for (const layer of domain.layers ?? []) {
      add('normativeLayer', `${domain.domain}:${layer.revision}`, 'retained', { source: layer.file });
    }
  }
  for (const artifact of contract.machineArtifacts ?? []) {
    if (artifact.id === 'implementationPlan') continue;
    add('machineArtifact', artifact.id, 'retained', { source: artifact.file });
  }

  // Plan governance artifacts (schema, manifest, audit, review, verifier).
  const planArtifact = (contract.machineArtifacts ?? []).find((a) => a.id === 'implementationPlan');
  const planVerifier = (contract.verificationTools ?? []).find((t) => t.id === 'planVerifier');
  for (const [id, source] of [
    ['schema', planArtifact?.schemaFile],
    ['manifest', planArtifact?.planFile],
    ['audit', planArtifact?.planAuditFile],
    ['adversarialReview', planArtifact?.adversarialReviewFile],
    ['verifier', planVerifier?.file],
  ]) {
    if (source) add('planArtifact', id, 'structural-plan-governance', { source });
  }

  // Public surface from the inherited G5-R declaration + scope manifests.
  const publicRows = Object.values(declarations.publicDeclarations ?? {}).flat();
  for (const row of publicRows) add('publicPath', row.path, row.disposition);
  for (const row of scope.sourceGraph?.featureEntries ?? []) add('feature', row.id, row.disposition);
  const regs = scope.registries ?? {};
  for (const row of regs.actions ?? []) add('action', row.id, row.disposition);
  for (const row of regs.pureTextSupportedActions ?? []) add('pureTextAction', row.id, row.disposition);
  for (const row of regs.contributions ?? []) add('contribution', row.id, row.disposition);
  for (const row of regs.commands ?? []) add('command', row.id, row.disposition);
  for (const row of regs.keybindings ?? []) {
    add('keybinding', `${String(row.ordinal).padStart(3, '0')}:${row.command}`, 'retained');
  }
  for (const menu of regs.menus ?? []) {
    add('menu', menu.id, menu.disposition ?? 'retained');
    for (const item of menu.items ?? []) {
      add('menuItem', `${menu.id}#${String(item.ordinal).padStart(3, '0')}`, 'retained');
    }
  }
  for (const row of regs.menuCommands ?? []) add('menuCommand', row.id, 'retained');
  for (const row of regs.options ?? []) add('option', row.name, row.disposition);
  for (const row of regs.colors ?? []) add('color', row.id, 'retained');
  for (const row of regs.icons ?? []) add('icon', row.id, 'retained');
  for (const row of regs.builtinThemes ?? []) add('theme', row.id, 'retained');
  for (const row of regs.languageDescriptors ?? []) add('languageDescriptor', row.id, row.disposition);
  for (const row of localization.localeProfiles ?? []) add('localizationProfile', row.id, 'retained');

  // Language providers (27 public + 3 internal = 30).
  const publicProviderRows = publicRows
    .filter((row) => /^languages\.register.*Provider(?:Factory)?$/.test(row.path))
    .sort((a, b) => a.path.localeCompare(b.path, 'en'));
  const directPublicProviders = new Set([
    'languages.registerTokensProviderFactory',
    'languages.registerNewSymbolNameProvider',
  ]);
  for (const row of publicProviderRows) {
    add(
      'provider',
      row.path,
      directPublicProviders.has(row.path) ? 'retained-direct-only' : 'retained-lsp-backed',
    );
  }
  for (const id of INTERNAL_DIRECT_PROVIDER_IDS) {
    add('provider', id, 'retained-direct-only', { source: 'L2-R fixed internal registry' });
  }

  // Host groups, correctness gates, performance workloads, candidate artifacts.
  for (const row of host.groups ?? []) add('hostGroup', row.id, 'retained');
  for (const id of contract.acceptance?.correctnessGates ?? []) add('correctnessGate', id, 'retained');
  for (const id of contract.performanceDecision?.workloads ?? []) add('performanceWorkload', id, 'retained');
  for (const row of contract.candidateGeneratedArtifacts ?? []) add('candidateArtifact', row.file, 'retained');

  identities.sort(sortIdentities);
  const counts = {};
  for (const identity of identities) counts[identity.kind] = (counts[identity.kind] ?? 0) + 1;
  return {
    schemaVersion: 1,
    identities,
    retained: identities.filter((i) => i.retained),
    dispositionOnly: identities.filter((i) => !i.retained),
    counts: Object.fromEntries(Object.entries(counts).sort(([a], [b]) => a.localeCompare(b, 'en'))),
  };
}

/**
 * The canonical identity key for an ownership/inventory row.
 */
export const identityKey = (row) => `${row.kind}:${row.id}`;
