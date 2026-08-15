import fs from 'node:fs';
import path from 'node:path';

const INTERNAL_DIRECT_PROVIDER_IDS = [
  'MultiDocumentHighlight',
  'DocumentPasteEdit',
  'DocumentDropEdit'
];

const retainedDisposition = (disposition) => (
  !disposition.startsWith('cut')
  && !disposition.startsWith('later')
  && disposition !== 'structural-plan-governance'
);

const sortIdentities = (left, right) => (
  left.kind.localeCompare(right.kind, 'en')
  || left.id.localeCompare(right.id, 'en')
);

export function buildContractInventory(artifactDirectory) {
  const load = (name) => JSON.parse(fs.readFileSync(path.join(artifactDirectory, name), 'utf8'));
  const g4 = load('monacode-g4r-authoritative-manifest.json');
  const g5 = load('monacode-g5r-authoritative-manifest.json');
  const scope = load('monaco-0.56.0-f1r3-scope-manifest.json');
  const declarations = load('monaco-0.56.0-f1r4-public-declaration-manifest.json');
  const host = load('monacode-h1r2-host-group-correction-manifest.json');
  const localization = load('monacode-n1r-localization-manifest.json');
  const identities = [];
  const keys = new Set();

  function add(kind, id, disposition = 'retained', details = {}) {
    const stringID = String(id);
    const key = `${kind}:${stringID}`;
    if (keys.has(key)) throw new Error(`duplicate contract inventory identity: ${key}`);
    keys.add(key);
    identities.push({
      kind,
      id: stringID,
      disposition,
      retained: retainedDisposition(disposition),
      ...details
    });
  }

  for (const domain of g4.normativeDomains) {
    for (const layer of domain.layers) {
      add('normativeLayer', `${domain.domain}:${layer.revision}`, 'retained', {
        source: layer.file
      });
    }
  }
  for (const artifact of g4.machineArtifacts) {
    add('machineArtifact', artifact.id, 'retained', { source: artifact.file });
  }

  const planArtifact = g5.machineArtifacts.find((artifact) => artifact.id === 'implementationPlan');
  const planVerifier = g5.verificationTools.find((tool) => tool.id === 'planVerifier');
  for (const [id, source] of [
    ['schema', planArtifact.schemaFile],
    ['manifest', planArtifact.planFile],
    ['audit', planArtifact.planAuditFile],
    ['adversarialReview', planArtifact.adversarialReviewFile],
    ['verifier', planVerifier.file]
  ]) {
    add('planArtifact', id, 'structural-plan-governance', { source });
  }

  const publicRows = Object.values(declarations.publicDeclarations).flat();
  for (const row of publicRows) add('publicPath', row.path, row.disposition);
  for (const row of scope.sourceGraph.featureEntries) add('feature', row.id, row.disposition);
  for (const row of scope.registries.actions) add('action', row.id, row.disposition);
  for (const row of scope.registries.pureTextSupportedActions) add('pureTextAction', row.id, row.disposition);
  for (const row of scope.registries.contributions) add('contribution', row.id, row.disposition);
  for (const row of scope.registries.commands) add('command', row.id, row.disposition);
  for (const row of scope.registries.keybindings) {
    add('keybinding', `${String(row.ordinal).padStart(3, '0')}:${row.command}`, 'retained');
  }
  for (const menu of scope.registries.menus) {
    add('menu', menu.id, menu.disposition ?? 'retained');
    for (const item of menu.items) {
      add('menuItem', `${menu.id}#${String(item.ordinal).padStart(3, '0')}`, 'retained');
    }
  }
  for (const row of scope.registries.menuCommands) add('menuCommand', row.id, 'retained');
  for (const row of scope.registries.options) add('option', row.name, row.disposition);
  for (const row of scope.registries.colors) add('color', row.id, 'retained');
  for (const row of scope.registries.icons) add('icon', row.id, 'retained');
  for (const row of scope.registries.builtinThemes) add('theme', row.id, 'retained');
  for (const row of scope.registries.languageDescriptors) add('languageDescriptor', row.id, row.disposition);
  for (const row of localization.localeProfiles) add('localizationProfile', row.id, 'retained');

  const publicProviderRows = publicRows
    .filter((row) => /^languages\.register.*Provider(?:Factory)?$/.test(row.path))
    .sort((left, right) => left.path.localeCompare(right.path, 'en'));
  const directPublicProviders = new Set([
    'languages.registerTokensProviderFactory',
    'languages.registerNewSymbolNameProvider'
  ]);
  for (const row of publicProviderRows) {
    add(
      'provider',
      row.path,
      directPublicProviders.has(row.path) ? 'retained-direct-only' : 'retained-lsp-backed'
    );
  }
  for (const id of INTERNAL_DIRECT_PROVIDER_IDS) {
    add('provider', id, 'retained-direct-only', { source: 'L2-R fixed internal registry' });
  }
  if (publicProviderRows.length !== 27 || identities.filter((row) => row.kind === 'provider').length !== 30) {
    throw new Error('provider inventory does not match the fixed 27 public plus 3 internal registry surface');
  }

  for (const row of host.groups) add('hostGroup', row.id, 'retained');
  for (const id of g5.acceptance.correctnessGates) add('correctnessGate', id, 'retained');
  for (const id of g5.performanceDecision.workloads) add('performanceWorkload', id, 'retained');
  for (const row of g5.candidateGeneratedArtifacts) add('candidateArtifact', row.file, 'retained');

  identities.sort(sortIdentities);
  const counts = {};
  for (const identity of identities) counts[identity.kind] = (counts[identity.kind] ?? 0) + 1;
  return {
    schemaVersion: 1,
    identities,
    retained: identities.filter((identity) => identity.retained),
    dispositionOnly: identities.filter((identity) => !identity.retained),
    counts: Object.fromEntries(Object.entries(counts).sort(([left], [right]) => left.localeCompare(right, 'en'))),
    sourceCounts: {
      inheritedNormativeLayers: 42,
      inheritedMachineArtifacts: 17,
      publicPaths: 555,
      features: 64,
      providers: 30,
      correctnessGates: 10,
      performanceWorkloads: 14,
      candidateArtifacts: 7
    }
  };
}
