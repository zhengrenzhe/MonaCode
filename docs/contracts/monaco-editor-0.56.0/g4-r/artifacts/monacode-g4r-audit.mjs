import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
const mutation = process.env.MONACODE_G4_AUDIT_MUTATION ?? '';
const failures = [];
const cache = new Map();

const check = (id, actual, expected) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) failures.push({ id, actual, expected });
};
const sum = object => Object.values(object).reduce((total, value) => total + value, 0);
const shaBytes = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const sha = name => shaBytes(fs.readFileSync(path.join(root, name)));

function duplicateObjectKeys(text, file) {
  let index = 0;
  const duplicates = [];
  const whitespace = () => {
    while (/\s/.test(text[index] ?? '')) index += 1;
  };
  const syntax = message => {
    throw new Error(`${file}:${index}: ${message}`);
  };
  const string = () => {
    whitespace();
    if (text[index] !== '"') syntax('expected JSON string');
    const start = index;
    index += 1;
    while (index < text.length) {
      if (text[index] === '"') {
        index += 1;
        return JSON.parse(text.slice(start, index));
      }
      if (text[index] === '\\') {
        index += 1;
        if (text[index] === 'u') index += 5;
        else index += 1;
      } else {
        index += 1;
      }
    }
    syntax('unterminated JSON string');
  };
  const pointerKey = key => key.replaceAll('~', '~0').replaceAll('/', '~1');
  const value = pointer => {
    whitespace();
    if (text[index] === '{') return object(pointer);
    if (text[index] === '[') return array(pointer);
    if (text[index] === '"') return void string();
    const start = index;
    while (index < text.length && !/[\s,}\]]/.test(text[index])) index += 1;
    if (start === index) syntax('expected JSON value');
    JSON.parse(text.slice(start, index));
  };
  const object = pointer => {
    index += 1;
    whitespace();
    const keys = new Set();
    if (text[index] === '}') return void (index += 1);
    while (index < text.length) {
      const key = string();
      const keyPointer = `${pointer}/${pointerKey(key)}`;
      if (keys.has(key)) duplicates.push({ file, pointer: keyPointer });
      keys.add(key);
      whitespace();
      if (text[index] !== ':') syntax('expected colon');
      index += 1;
      value(keyPointer);
      whitespace();
      if (text[index] === '}') return void (index += 1);
      if (text[index] !== ',') syntax('expected comma');
      index += 1;
    }
    syntax('unterminated JSON object');
  };
  const array = pointer => {
    index += 1;
    whitespace();
    let item = 0;
    if (text[index] === ']') return void (index += 1);
    while (index < text.length) {
      value(`${pointer}/${item}`);
      item += 1;
      whitespace();
      if (text[index] === ']') return void (index += 1);
      if (text[index] !== ',') syntax('expected comma');
      index += 1;
    }
    syntax('unterminated JSON array');
  };
  value('$');
  whitespace();
  if (index !== text.length) syntax('trailing JSON content');
  return duplicates;
}

function read(name) {
  if (cache.has(name)) return cache.get(name);
  let raw = fs.readFileSync(path.join(root, name), 'utf8');
  if (name === 'monacode-g4r-authoritative-manifest.json' && mutation === 'duplicate-key') {
    raw = raw.replace('"schemaVersion": 2,', '"schemaVersion": 2,\n  "schemaVersion": 2,');
  }
  for (const duplicate of duplicateObjectKeys(raw, name)) {
    failures.push({ id: 'duplicate-json-key', actual: duplicate, expected: null });
  }
  const parsed = JSON.parse(raw);
  cache.set(name, parsed);
  return parsed;
}

for (const name of fs.readdirSync(root).filter(name => name.endsWith('.json')).sort()) read(name);

const g = read('monacode-g4r-authoritative-manifest.json');
if (mutation === 'public-count') g.surfaceCounts.publicDeclarations.total += 1;
if (mutation === 'normative-hash') g.normativeDomains[0].layers[0].sha256 = '0'.repeat(64);
if (mutation === 'privacy-field') g.currentLocalEnvironment.hardwareUUID = ['01234567', '89AB', 'CDEF', '0123', '456789ABCDEF'].join('-');
if (mutation === 'candidate-removal') g.candidateGeneratedArtifacts.pop();
if (mutation === 'host-count') g.surfaceCounts.nativeEmbedding.hostContractGroups = 8;
if (mutation === 'localization-count') g.surfaceCounts.uiLocalization.selectableProfiles = 14;
if (mutation === 'markdown-member') g.surfaceCounts.markdown.retainedInputMembers = 7;
if (mutation === 'service-disposition') g.surfaceCounts.standaloneServices.classifiedRegistrations = 39;
if (mutation === 'environment-count') g.surfaceCounts.environmentIntl.mathRandomOccurrences = 7;
if (mutation === 'source-closure') g.surfaceCounts.sourceRuntimeStyle.directGlobalReferences = 8220;
if (mutation === 'runtime-visual-count') g.surfaceCounts.sourceRuntimeStyle.targetedVisualMutationSites = 3098;
if (mutation === 'package-inventory') g.surfaceCounts.sourceRuntimeStyle.unreachablePackageJavaScriptFiles = 37;
if (mutation === 'implicit-effect-count') g.surfaceCounts.sourceRuntimeStyle.implicitExternalEffectSites = 13;
if (mutation === 'uri-visual-producer') g.surfaceCounts.sourceRuntimeStyle.retainedUriBackedVisualProducerPaths = 1;
if (mutation === 'historical-exception') g.designClosure.historicalPreflightExceptions.pop();
if (mutation === 'snippet-variable') g.surfaceCounts.snippetEngine.knownVariables = 38;
if (mutation === 'diff-cache') g.surfaceCounts.diffEngine.processCacheMaximumEntries = 10;

const scope = read('monaco-0.56.0-f1r3-scope-manifest.json');
const instances = read('monaco-0.56.0-f1r3-instance-surface-manifest.json');
const pub = read('monaco-0.56.0-f1r4-public-declaration-manifest.json');
const types = read('monacode-f1r5-native-type-contract-manifest.json');
const regexp = read('monacode-m1r3-regexp-unicode-manifest.json');
const environment = read('monacode-e1r-environment-intl-clock-entropy-manifest.json');
const sourceRuntimeStyle = read('monacode-x1r-source-runtime-style-manifest.json');
const localization = read('monacode-n1r-localization-manifest.json');
const markdown = read('monacode-md1r-markdown-contract-manifest.json');
const services = read('monacode-s1r-standalone-service-contract-manifest.json');
const snippet = read('monacode-sn1r-snippet-engine-manifest.json');
const diff = read('monacode-d1r-diff-engine-manifest.json');
const ax = read('monaco-0.56.0-a2r-accessibility-manifest.json');
const h1 = read('monacode-h1r-native-boundary-manifest.json');
const h1r2 = read('monacode-h1r2-host-group-correction-manifest.json');
const h2 = read('monacode-h2r-runtime-resource-manifest.json');
const q = read('monacode-q1r5-acceptance-manifest.json');

const expectedTopLevelKeys = [
  'acceptance', 'architecture', 'authorityArtifacts', 'authorityRules', 'baselineInertPaths',
  'candidateGeneratedArtifacts', 'currentLocalEnvironment', 'deliveryScope', 'designClosure',
  'empiricalStatus', 'equivalenceDomains', 'explicitCuts', 'hostContractClosure', 'identity',
  'implementationOutputRules', 'licensingProfile', 'machineArtifacts', 'nativeReplacements',
  'normativeDomains', 'performanceDecision', 'schemaVersion', 'surfaceCounts', 'validationScope',
  'verificationTools'
].sort();
check('g4-top-level-keys', Object.keys(g).sort(), expectedTopLevelKeys);
check('g4-schema', g.schemaVersion, 2);
check('g4-revision', g.identity.revision, 'G4-R-full-scope-candidate');
check('g4-status', g.identity.status, 'design-baseline-only');
check('current-release', g.identity.currentRelease, 'arm64 macOS');
check('deployment-target', g.validationScope.packageDeploymentTarget, 'macOS 26.0');
check('runtime-qualified-environment', g.validationScope.runtimeQualifiedEnvironment, 'the current arm64 machine on macOS 26.6 build 25G72 only');
check('language-implementations-zero', g.surfaceCounts.languageContent.shippedLanguageImplementations, 0);
check('bundled-lsp-zero', g.surfaceCounts.languageContent.bundledLspServers, 0);
check('production-dependencies', g.architecture.dependencies, 'no third-party production runtime');
check('metal-trigger', g.performanceDecision.metalTrigger, 'only a failed renderer-owned metric after a correct full Core Graphics implementation triggers Metal work');

const refs = [];
function walk(value, pointer = '$') {
  if (!value || typeof value !== 'object') return;
  if (!Array.isArray(value) && typeof value.file === 'string' && /^[0-9a-f]{64}$/.test(value.sha256 ?? '')) {
    const target = path.join(root, value.file);
    refs.push({ pointer, file: value.file, exists: fs.existsSync(target), expected: value.sha256, actual: fs.existsSync(target) ? sha(value.file) : null });
  }
  if (Array.isArray(value)) value.forEach((item, itemIndex) => walk(item, `${pointer}[${itemIndex}]`));
  else Object.entries(value).forEach(([key, item]) => walk(item, `${pointer}.${key}`));
}
walk(g);
for (const ref of refs) {
  check(`ref-exists:${ref.pointer}`, ref.exists, true);
  if (ref.exists) check(`ref-hash:${ref.pointer}`, ref.actual, ref.expected);
}
check('unique-reference-files', new Set(refs.map(item => item.file)).size, refs.length);

const requiredRevisions = [
  'P1-R', 'M1-R', 'M1-R2', 'M1-R3', 'E1-R', 'X1-R', 'B1-R', 'A+', 'A+-base', 'R1', 'I3-R', 'I3-R2',
  'I3-R3', 'I3-R4', 'I4-R', 'V1-R3', 'V1-R4', 'L2-R', 'L2-R2', 'L2-R3', 'F1-R',
  'F1-R2', 'F1-R3', 'F1-R4', 'F1-R5', 'SN1-R', 'D1-R', 'T1-R', 'N1-R', 'MD1-R', 'S1-R', 'A1-R', 'A1-R2', 'A2-R2', 'H1-R',
  'H1-R2', 'H2-R', 'Q1-R', 'Q1-R2', 'Q1-R3', 'Q1-R4', 'Q1-R5'
];
const revisions = g.normativeDomains.flatMap(domain => domain.layers.map(layer => layer.revision));
check('normative-revisions', revisions, requiredRevisions);
check('unique-normative-revisions', new Set(revisions).size, revisions.length);
const expectedMachineIds = [
  'F1-R3-scope', 'F1-R3-instance', 'F1-R4-public', 'F1-R5-native-types', 'A2-R2-accessibility',
  'M1-R3-regexp-unicode', 'E1-R-environment-intl', 'X1-R-source-runtime-style', 'N1-R-localization', 'MD1-R-markdown', 'S1-R-standalone-services', 'SN1-R-snippet-engine', 'D1-R-diff-engine', 'H1-R-native-boundary', 'H1-R2-host-group', 'H2-R-runtime-resource',
  'Q1-R5-acceptance'
];
check('machine-ids', g.machineArtifacts.map(item => item.id), expectedMachineIds);
check('unique-machine-ids', new Set(g.machineArtifacts.map(item => item.id)).size, g.machineArtifacts.length);
check('verification-tools', g.verificationTools.map(item => item.file), ['monacode-g4r-audit.mjs']);

const registryToCount = {
  actions: 'actions', pureTextSupportedActions: 'pureTextSupportedActions', contributions: 'contributions',
  diffContributions: 'diffContributions', commands: 'commands', keybindings: 'keybindings', menus: 'menus',
  menuCommands: 'menuCommands', options: 'options', languageDescriptors: 'languageDescriptors', colors: 'colors',
  icons: 'icons', builtinThemes: 'builtinThemes'
};
for (const [registry, countKey] of Object.entries(registryToCount)) {
  check(`scope-${registry}-length`, scope.registries[registry].length, scope.counts[countKey]);
}
const namespaceCountKeys = { topLevel: 'topLevelExports', editor: 'editorNamespace', languages: 'languageNamespace', lsp: 'lspNamespace' };
for (const [namespace, rows] of Object.entries(scope.namespaces)) {
  check(`scope-${namespace}-length`, rows.length, scope.counts[namespaceCountKeys[namespace]]);
}

const rows = Object.values(pub.publicDeclarations).flat();
const retained = rows.filter(row => row.disposition.startsWith('retained-')).length;
const cut = rows.filter(row => row.disposition.startsWith('cut-')).length;
const originalDispositions = Object.fromEntries([...new Set(rows.map(row => row.disposition))].sort().map(disposition => [disposition, rows.filter(row => row.disposition === disposition).length]));
check('public-manifest-total', rows.length, pub.counts.totalPublicDeclarationPaths);
check('public-manifest-dispositions', originalDispositions, pub.counts.dispositions);
check('public-namespace-total', sum(Object.fromEntries(Object.entries(pub.counts.byNamespace).map(([key, item]) => [key, item.declarations]))), rows.length);
check('public-total', g.surfaceCounts.publicDeclarations.total, rows.length);
check('public-retained', g.surfaceCounts.publicDeclarations.retained, retained);
check('public-cut', g.surfaceCounts.publicDeclarations.cut, cut);
check('retained-disposition-sum', sum(g.surfaceCounts.publicDeclarations.retainedDispositionCountsAfterMD1), retained);
check('cut-disposition-sum', sum(g.surfaceCounts.publicDeclarations.cutDispositionCounts), cut);
check('corrected-mapping', g.surfaceCounts.publicDeclarations.retainedDispositionCountsAfterMD1['retained-native-mapping'], markdown.dispositionCorrection.correctedDispositionCounts['retained-native-mapping']);
check('corrected-member-cut-paths', g.surfaceCounts.publicDeclarations.retainedDispositionCountsAfterMD1['retained-with-explicit-member-cuts'], markdown.dispositionCorrection.correctedDispositionCounts['retained-with-explicit-member-cuts']);
check('explicit-member-cuts', g.surfaceCounts.publicDeclarations.explicitMemberCuts.total, markdown.dispositionCorrection.explicitMemberCuts.total);
check('pre-markdown-mapping', markdown.dispositionCorrection.correctedDispositionCounts['retained-native-mapping'] + 1, types.dispositionCorrection.correctedDispositionCounts['retained-native-mapping']);
check('pre-markdown-member-cut-paths', markdown.dispositionCorrection.correctedDispositionCounts['retained-with-explicit-member-cuts'] - 1, types.dispositionCorrection.correctedDispositionCounts['retained-with-explicit-member-cuts']);
check('pre-markdown-explicit-member-cuts', markdown.dispositionCorrection.explicitMemberCuts.previous, types.dispositionCorrection.explicitMemberCuts.total);

for (const [name, item] of Object.entries(instances.interfaces)) {
  check(`instance-${name}-decl-array`, item.fullDeclarations.length, item.fullDeclarationCount);
  check(`instance-${name}-unique-array`, item.fullUniqueMembers.length, item.fullUniqueCount);
  check(`instance-${name}-decl`, g.surfaceCounts.editorInstances[name].declarations, item.fullDeclarationCount);
  check(`instance-${name}-unique`, g.surfaceCounts.editorInstances[name].uniqueMembers, item.fullUniqueCount);
}
check('features-baseline', g.surfaceCounts.features.baseline, scope.counts.featureEntries);
check('features-partition', g.surfaceCounts.features.retainedMacOS + g.surfaceCounts.features.laterIPadOS + g.surfaceCounts.features.cutWebGPUDebug, scope.counts.featureEntries);
check('actions-baseline', g.surfaceCounts.actions.baseline, scope.counts.actions);
check('actions-partition', g.surfaceCounts.actions.retained + g.surfaceCounts.actions.cut, scope.counts.actions);
check('pure-actions-baseline', g.surfaceCounts.pureTextActions.baseline, scope.counts.pureTextSupportedActions);
check('commands-baseline', g.surfaceCounts.commands.baseline, scope.counts.commands);
check('contributions-baseline', g.surfaceCounts.contributions.baseline, scope.counts.contributions);
check('keybindings', g.surfaceCounts.keybindings, scope.counts.keybindings);
check('menus', g.surfaceCounts.menus, scope.counts.menus);
check('menu-items', g.surfaceCounts.menuItems, scope.counts.menuItems);
check('menu-command-descriptors', g.surfaceCounts.menuCommandDescriptors, scope.counts.menuCommands);
check('options-baseline', g.surfaceCounts.options.baseline, scope.counts.options);
check('options-partition', g.surfaceCounts.options.retainedInput + g.surfaceCounts.options.computedOnly + g.surfaceCounts.options.cut, scope.counts.options);
for (const [key, namespace] of Object.entries(g.surfaceCounts.runtimeNamespaces)) check(`runtime-${key}`, namespace.baseline, scope.namespaces[key].length);
check('runtime-top-partition', g.surfaceCounts.runtimeNamespaces.topLevel.retainedNativeMapping + g.surfaceCounts.runtimeNamespaces.topLevel.retainedAndExtendedLsp + g.surfaceCounts.runtimeNamespaces.topLevel.cutBuiltinLanguagePack, scope.namespaces.topLevel.length);
check('runtime-editor-partition', g.surfaceCounts.runtimeNamespaces.editor.retainedNativeMapping + g.surfaceCounts.runtimeNamespaces.editor.nativeReplacement + g.surfaceCounts.runtimeNamespaces.editor.cutWebWorker, scope.namespaces.editor.length);
check('runtime-language-partition', g.surfaceCounts.runtimeNamespaces.languages.retainedNativeMapping + g.surfaceCounts.runtimeNamespaces.languages.cutMonarch, scope.namespaces.languages.length);
check('runtime-lsp-partition', g.surfaceCounts.runtimeNamespaces.lsp.retainedAndExtendedClient + g.surfaceCounts.runtimeNamespaces.lsp.cutWebTransport, scope.namespaces.lsp.length);

check('regexp-references', g.surfaceCounts.regexpUnicode.publicReferences, regexp.publicRegExpReferences.total);
check('regexp-retained', g.surfaceCounts.regexpUnicode.retainedReferences, regexp.publicRegExpReferences.retained);
check('regexp-cut', g.surfaceCounts.regexpUnicode.cutReferences, regexp.publicRegExpReferences.cut);
check('regexp-profiles', g.surfaceCounts.regexpUnicode.consumerProfiles, regexp.regexpProfiles.length);
check('unicode-profiles', g.surfaceCounts.regexpUnicode.unicodeProfiles, regexp.unicodeProfiles.length);
check('regexp-public-partition', regexp.publicRegExpReferences.retained + regexp.publicRegExpReferences.cut, regexp.publicRegExpReferences.total);
check('regexp-retained-fields', regexp.publicRegExpReferences.retainedFields.length, regexp.publicRegExpReferences.retained);
check('regexp-cut-fields', regexp.publicRegExpReferences.cutFields.length, regexp.publicRegExpReferences.cut);

const effects = environment.sourceEffectClosure.syntaxCounts;
check('environment-source-closure', g.surfaceCounts.environmentIntl.reachableJavaScriptFiles, environment.sourceEffectClosure.reachableJavaScriptFiles);
check('environment-service-closure-equal', environment.sourceEffectClosure.reachableJavaScriptFiles, services.sourceClosure.reachableJavaScriptFiles);
check('environment-style-closure', g.surfaceCounts.environmentIntl.reachableStyleResources, environment.sourceEffectClosure.reachableStyleResources);
check('environment-total-closure', g.surfaceCounts.environmentIntl.totalImportedFiles, environment.sourceEffectClosure.totalImportedFiles);
check('environment-closure-sum', environment.sourceEffectClosure.reachableJavaScriptFiles + environment.sourceEffectClosure.reachableStyleResources, environment.sourceEffectClosure.totalImportedFiles);
check('environment-import-edges', g.surfaceCounts.environmentIntl.importEdges, environment.sourceEffectClosure.parsedImportEdges);
check('environment-external-static-zero', environment.sourceEffectClosure.externalStaticImports, 0);
check('environment-js-set-sha', environment.sourceEffectClosure.reachableJavaScriptSetSha256, sourceRuntimeStyle.authorities.syntaxScan.reachableJavaScriptSetSha256);
check('environment-style-set-sha', environment.sourceEffectClosure.reachableStyleResourceSetSha256, sourceRuntimeStyle.authorities.syntaxScan.reachableStyleResourceSetSha256);
check('environment-default-case', g.surfaceCounts.environmentIntl.defaultCaseOccurrences, effects.toUpperCase.occurrences + effects.toLowerCase.occurrences);
check('environment-locale-case', g.surfaceCounts.environmentIntl.localeCaseOccurrences, effects.toLocaleUpperCase.occurrences + effects.toLocaleLowerCase.occurrences);
check('environment-locale-compare', g.surfaceCounts.environmentIntl.localeCompareOccurrences, effects.localeCompare.occurrences);
check('environment-normalization', g.surfaceCounts.environmentIntl.normalizationOccurrences, effects.unicodeNormalize.occurrences);
check('environment-random', g.surfaceCounts.environmentIntl.mathRandomOccurrences, effects.mathRandom.occurrences);
check('environment-date-now', g.surfaceCounts.environmentIntl.dateNowOccurrences, effects.dateNow.occurrences);
check('environment-new-date', g.surfaceCounts.environmentIntl.newDateOccurrences, effects.newDate.occurrences);
check('environment-stopwatch-sites', g.surfaceCounts.environmentIntl.stopWatchConstructionSites, effects.stopWatchConstructionSites.occurrences);
check('environment-stopwatch-high-resolution', g.surfaceCounts.environmentIntl.retainedHighResolutionStopWatchSites, effects.stopWatchConstructionSites.retainedHighResolution);
check('environment-stopwatch-wall-clock', g.surfaceCounts.environmentIntl.retainedWallClockStopWatchSites, effects.stopWatchConstructionSites.retainedWallClock);
check('environment-input-latency-performance', g.surfaceCounts.environmentIntl.inputLatencyPerformanceCalls, effects.inputLatencyPerformanceApi.occurrences);
check('environment-timers', g.surfaceCounts.environmentIntl.timerOccurrences, effects.timerCalls.occurrences);
check('environment-microtasks', g.surfaceCounts.environmentIntl.microtaskOccurrences, effects.queueMicrotask.occurrences);
check('environment-collation-profiles', g.surfaceCounts.environmentIntl.collationProfiles, environment.textSemantics.collationProfiles.length);
check('environment-normalization-caches', g.surfaceCounts.environmentIntl.activeNormalizationCaches, ['nfdCache', 'baseCache'].filter(key => environment.textSemantics.normalization[key]?.capacity === 10000).length);
check('environment-runtime-locale', g.currentLocalEnvironment.runtimeLocale, environment.qualifiedRuntimeObservation.chromeIntlResolvedLocale);
check('environment-runtime-calendar', g.currentLocalEnvironment.runtimeCalendar, environment.qualifiedRuntimeObservation.chromeCalendar);
check('environment-runtime-numbering', g.currentLocalEnvironment.runtimeNumberingSystem, environment.qualifiedRuntimeObservation.chromeNumberingSystem);
check('environment-runtime-time-zone', g.currentLocalEnvironment.runtimeTimeZone, environment.qualifiedRuntimeObservation.chromeTimeZone);
check('environment-icu-version', g.currentLocalEnvironment.chromeIcu, environment.authorities.chrome.icuVersion);
check('environment-icu-data', g.currentLocalEnvironment.chromeIcuDataSha256, environment.authorities.chrome.localIcuDataSha256);
check('environment-time-source-file', environment.authorities.chrome.timeSource.file, 'base/time/time_apple.mm');
check('environment-time-source-sha', environment.authorities.chrome.timeSource.sha256, '0015cb2fa5ee082bb61f07e24c150d161b08a7148143914d43c58f4850c68134');
check('environment-high-resolution-domain', environment.clocksAndScheduling.highResolutionClock.includes('mach_absolute_time'), true);
check('environment-direct-performance-cut', effects.directPerformanceNow.disposition, 'cut-tree-sitter');
check('environment-random-vectors', environment.entropy.snippetVectors, [
  { double: '0.123456789', variable: 'RANDOM', output: '456789' },
  { double: '0.5', variable: 'RANDOM_HEX', output: '0.8' },
  { double: '0.9999999999999999', variable: 'RANDOM', output: '999999' },
  { double: '0.00000123456789', variable: 'RANDOM_HEX', output: '15e19b' }
]);
check('environment-unicode-input-count', environment.authorities.unicodeInputs.length, 5);
check('environment-source-zero', environment.implementationStatus.nativeEnvironmentSourceFiles, 0);
check('environment-generated-zero', environment.implementationStatus.generatedUnicodeIntlTables, 0);
check('environment-classified-zero', environment.implementationStatus.classifiedSensitiveOccurrences, 0);
check('environment-not-passed', environment.implementationStatus.verdict, 'not-passed');

const xScan = sourceRuntimeStyle.authorities.syntaxScan;
const xModules = sourceRuntimeStyle.moduleAndResourceClosure;
const xPackage = xModules.packageInventory;
const xUnreachableJavaScript = xModules.unreachableVsJavaScript;
const xGlobals = sourceRuntimeStyle.directGlobalClosure;
const xStyles = sourceRuntimeStyle.styleResourceClosure;
const xStyleSyntax = xStyles.sourceSyntaxScan;
const xStyleVariables = xStyles.styleVariableClosure;
const xRuntimeVisual = xStyles.runtimeVisualMutationClosure;
const xClock = sourceRuntimeStyle.clockAndPerformanceCorrection;
const xEncoding = sourceRuntimeStyle.encodingAndHashing;
const xImplicitExternalEffects = sourceRuntimeStyle.platformEffectDispositions.implicitExternalEffectClosure;
const xUriVisualAssets = xImplicitExternalEffects.uriBackedVisualAssets;
check('source-schema', sourceRuntimeStyle.schemaVersion, 1);
check('source-revision', sourceRuntimeStyle.identity.revision, 'X1-R-source-runtime-style-closure');
check('source-status', sourceRuntimeStyle.identity.status, 'design-baseline-only');
check('source-core-tar', sourceRuntimeStyle.authorities.coreTarSha256, '78e222c77e7ef6402ea0bfb20e02caad7b63156f5d2798bc3c398a8bb396f4ed');
check('source-entry-file', sourceRuntimeStyle.authorities.entry.file, 'esm/vs/editor/editor.main.js');
check('source-entry-sha', sourceRuntimeStyle.authorities.entry.sha256, '2b9a37b9c886162a724ac98dac24455a2bafb7e445dca37a1315f4afde14bad2');
check('source-pinned-file-hashes', sourceRuntimeStyle.authorities.sourceFiles, [
  { file: 'esm/vs/base/common/stopwatch.js', sha256: '7df79844ab1f2f63920e0bab096d87e1ae65a6916ce658f4bb939d481d52d5cb' },
  { file: 'esm/vs/base/browser/performance.js', sha256: '3536bcefd6d828732c658e4af84a0a9646b87d16005ade958f0ca41f5fbf441f' },
  { file: 'esm/vs/base/common/hash.js', sha256: 'cb4c3dc17fd975d9d51d9523fc6291ec55fabf975af7e4c73c7ce0a7c3896c07' },
  { file: 'esm/vs/base/common/buffer.js', sha256: '2a0d552fd97a46052d2bce664c5edf71d6768057ca8e2f2394d8b567382a36c5' },
  { file: 'esm/vs/editor/common/core/stringBuilder.js', sha256: '4c20000d26b6437a5f76d2bad4473d0fa221b2c285651814cb8f7e0a2d2fb587' },
  { file: 'esm/vs/editor/common/languages/supports/richEditBrackets.js', sha256: '2a0be69d038b9616df589a901b19cb440d173a11e3cd2ac52b500db66fd762e2' }
]);
check('source-js-count', g.surfaceCounts.sourceRuntimeStyle.reachableJavaScriptFiles, xScan.reachableJavaScriptFiles);
check('source-style-count', g.surfaceCounts.sourceRuntimeStyle.reachableStyleResources, xScan.reachableStyleResources);
check('source-total-count', g.surfaceCounts.sourceRuntimeStyle.totalImportedFiles, xScan.totalImportedFiles);
check('source-total-sum', xScan.reachableJavaScriptFiles + xScan.reachableStyleResources, xScan.totalImportedFiles);
check('source-module-count-crosscheck', xModules.javascriptModules, xScan.reachableJavaScriptFiles);
check('source-style-count-crosscheck', xModules.styleResources, xScan.reachableStyleResources);
check('source-total-count-crosscheck', xModules.totalFiles, xScan.totalImportedFiles);
check('source-js-set-sha', xScan.reachableJavaScriptSetSha256, '0dd3fb5c14287788b9d5e4ebc2b990005adf6761abc5c4d9903e790c24dcf8fb');
check('source-style-set-sha', xScan.reachableStyleResourceSetSha256, '0b63cc441918733ded80464c17b3fbde1a5ded5b9136ea371dca93a403887c74');
check('source-import-edges', g.surfaceCounts.sourceRuntimeStyle.importEdges, xScan.importEdges);
check('source-external-static', g.surfaceCounts.sourceRuntimeStyle.externalStaticImports, xScan.externalStaticImports);
check('source-static-zero', xModules.staticExternalModuleSpecifiers, 0);
check('source-runtime-dynamic-count', g.surfaceCounts.sourceRuntimeStyle.runtimeDynamicImports, xModules.runtimeDynamicImportExpressions.length);
check('source-runtime-dynamic-file', xModules.runtimeDynamicImportExpressions.map(item => `${item.file}:${item.line}`), ['esm/vs/editor/common/diff/externalLinesDiffComputer.js:19']);
check('source-runtime-dynamic-disposition', xModules.runtimeDynamicImportExpressions.every(item => item.disposition.includes('D1 fixed-baseline unavailable')), true);
check('source-worker-string-count', xModules.generatedWorkerImportStrings, 1);
check('source-package-files', g.surfaceCounts.sourceRuntimeStyle.packageFiles, xPackage.files);
check('source-package-file-set-sha', xPackage.fileSetSha256, 'a33511c8772d626e9244777c3fe1cd6c9858f7da57400b39995cc0ea0e539d31');
check('source-package-javascript', g.surfaceCounts.sourceRuntimeStyle.packageJavaScriptFiles, xPackage.javascriptFiles);
check('source-package-javascript-set-sha', xPackage.javascriptFileSetSha256, '21175ce9c5c7f2dc19e7355742139bf145d6e8b024f2b07dda2a455591969f02');
check('source-package-vs-javascript', g.surfaceCounts.sourceRuntimeStyle.packageVsJavaScriptFiles, xPackage.vsJavaScriptFiles);
check('source-package-vs-javascript-set-sha', xPackage.vsJavaScriptFileSetSha256, '16b8cf052ef6c7e36f8a51cc2435da238fe7f5a326a4ff3485aae10c636c877a');
check('source-package-nls-javascript', g.surfaceCounts.sourceRuntimeStyle.packageNlsJavaScriptTables, xPackage.nlsJavaScriptTables);
check('source-package-nls-javascript-set-sha', xPackage.nlsJavaScriptFileSetSha256, '181406e49d13fa99f848846ae09c0e6a6c379bb5c5921b8feaa0ad5b4381070e');
check('source-package-javascript-partition', xPackage.vsJavaScriptFiles + xPackage.nlsJavaScriptTables, xPackage.javascriptFiles);
check('source-package-vs-reachability-partition', xScan.reachableJavaScriptFiles + xUnreachableJavaScript.count, xPackage.vsJavaScriptFiles);
check('source-package-source-maps', g.surfaceCounts.sourceRuntimeStyle.packageSourceMaps, xPackage.sourceMaps);
check('source-package-public-declarations', g.surfaceCounts.sourceRuntimeStyle.packagePublicDeclarationFiles, xPackage.publicDeclarationFiles);
check('source-package-other-binary-runtime-assets', g.surfaceCounts.sourceRuntimeStyle.packageOtherBinaryRuntimeAssets, xPackage.otherBinaryRuntimeAssets);
check('source-package-file-type-partition', xPackage.javascriptFiles + xPackage.styleFiles + xPackage.sourceMaps + xPackage.publicDeclarationFiles + xPackage.jsonFiles + xPackage.markdownFiles + xPackage.textFiles + xPackage.extensionlessLicenseFiles + xPackage.fontFiles, xPackage.files);
check('source-unreachable-javascript-count', g.surfaceCounts.sourceRuntimeStyle.unreachablePackageJavaScriptFiles, xUnreachableJavaScript.count);
check('source-unreachable-javascript-hash', xUnreachableJavaScript.fileSetSha256, '1cf6ed3e437fe0719a2fe61a5d374ed649d72a0168045f23cba4a7c210f1a54a');
check('source-unreachable-javascript-files', xUnreachableJavaScript.files, [
  'esm/vs/base/browser/contextmenu.js',
  'esm/vs/base/browser/history.js',
  'esm/vs/base/browser/ui/breadcrumbs/breadcrumbsWidget.js',
  'esm/vs/base/browser/ui/dialog/dialog.js',
  'esm/vs/base/browser/ui/hover/hoverDelegate.js',
  'esm/vs/base/browser/ui/radio/radio.js',
  'esm/vs/base/browser/ui/scrollbar/scrollableElementOptions.js',
  'esm/vs/base/browser/ui/table/table.js',
  'esm/vs/base/common/charCode.js',
  'esm/vs/base/common/defaultAccount.js',
  'esm/vs/base/common/jsonSchema.js',
  'esm/vs/base/common/marshallingIds.js',
  'esm/vs/base/common/paging.js',
  'esm/vs/base/common/policy.js',
  'esm/vs/base/common/product.js',
  'esm/vs/base/common/sequence.js',
  'esm/vs/base/common/stream.js',
  'esm/vs/base/common/worker/webWorkerBootstrap.js',
  'esm/vs/base/parts/sandbox/common/sandboxTypes.js',
  'esm/vs/editor/browser/controller/editContext/native/screenReaderUtils.js',
  'esm/vs/editor/browser/gpu/atlas/atlas.js',
  'esm/vs/editor/browser/gpu/gpu.js',
  'esm/vs/editor/browser/gpu/raster/raster.js',
  'esm/vs/editor/browser/widget/multiDiffEditor/model.js',
  'esm/vs/editor/browser/widget/multiDiffEditor/multiDiffEditorViewModel.js',
  'esm/vs/editor/browser/widget/multiDiffEditor/workbenchUIElementFactory.js',
  'esm/vs/editor/common/config/editorConfiguration.js',
  'esm/vs/editor/common/core/2d/dimension.js',
  'esm/vs/editor/common/cursorEvents.js',
  'esm/vs/editor/common/diff/documentDiffProvider.js',
  'esm/vs/editor/common/services/editorWebWorkerMain.js',
  'esm/vs/editor/common/services/textModelSync/textModelSync.protocol.js',
  'esm/vs/editor/common/tokenizationTextModelPart.js',
  'esm/vs/editor/common/viewModel/screenReaderSimpleModel.js',
  'esm/vs/editor/editor.worker.start.js',
  'esm/vs/editor/standalone/common/monarch/monarchTypes.js',
  'esm/vs/platform/actionWidget/common/actionWidget.js',
  'esm/vs/platform/telemetry/common/gdprTypings.js'
]);
check('source-unreachable-static-inbound-zero', xUnreachableJavaScript.staticEdgesFromReachableSet, 0);
check('source-unreachable-internal-edges', xUnreachableJavaScript.internalStaticEdges, 2);
check('source-unreachable-deep-import-cut', xUnreachableJavaScript.rule.includes('Direct internal ESM deep-import compatibility is outside the native public contract'), true);

const expectedIntrinsicGlobals = [
  'AggregateError', 'Array', 'ArrayBuffer', 'BigInt', 'Boolean', 'DataView', 'Date', 'decodeURIComponent',
  'encodeURI', 'encodeURIComponent', 'Error', 'Float32Array', 'Function', 'Infinity', 'Int32Array', 'Intl',
  'isFinite', 'isNaN', 'JSON', 'Map', 'Math', 'NaN', 'Number', 'Object', 'parseFloat', 'parseInt',
  'Promise', 'Proxy', 'Reflect', 'RegExp', 'Set', 'String', 'Symbol', 'TypeError', 'Uint16Array',
  'Uint32Array', 'Uint8Array', 'Uint8ClampedArray', 'undefined', 'WeakMap', 'WeakRef'
];
const expectedPlatformGlobals = [
  'Animation', 'Blob', 'Buffer', 'CSS', 'CSSImportRule', 'CSSStyleRule', 'ClipboardItem', 'DOMRect', 'Element',
  'GPUBufferUsage', 'GPUTextureUsage', 'HTMLAnchorElement', 'HTMLElement', 'IntersectionObserver', 'KeyboardEvent',
  'MouseEvent', 'MutationObserver', 'Node', 'OffscreenCanvas', 'ResizeObserver', 'SVGElement', 'ShadowRoot',
  'TextDecoder', 'TextEncoder', 'UIEvent', 'URL', 'URLSearchParams', 'Window', 'Worker', 'clearTimeout',
  'console', 'crypto', 'customElements', 'document', 'globalThis', 'importScripts', 'navigator', 'performance',
  'process', 'queueMicrotask', 'self', 'setTimeout', 'window'
];
const expectedAbsentGlobals = [
  'fetch', 'XMLHttpRequest', 'WebSocket', 'EventSource', 'localStorage', 'sessionStorage', 'indexedDB',
  'FileReader', 'atob', 'btoa', 'WebAssembly', 'SharedArrayBuffer', 'Atomics', 'FinalizationRegistry',
  'structuredClone', 'AudioContext', 'speechSynthesis', 'eval'
];
check('source-global-identifiers', g.surfaceCounts.sourceRuntimeStyle.directGlobalIdentifiers, xGlobals.identifierCount);
check('source-global-references', g.surfaceCounts.sourceRuntimeStyle.directGlobalReferences, xGlobals.referenceCount);
check('source-intrinsic-identifiers', g.surfaceCounts.sourceRuntimeStyle.ecmascriptIntrinsicIdentifiers, xGlobals.ecmascriptIntrinsicIdentifiers.count);
check('source-intrinsic-references', g.surfaceCounts.sourceRuntimeStyle.ecmascriptIntrinsicReferences, xGlobals.ecmascriptIntrinsicIdentifiers.references);
check('source-platform-identifiers', g.surfaceCounts.sourceRuntimeStyle.platformIdentifiers, xGlobals.platformIdentifiers.count);
check('source-platform-references', g.surfaceCounts.sourceRuntimeStyle.platformReferences, xGlobals.platformIdentifiers.references);
check('source-global-identifier-partition', xGlobals.ecmascriptIntrinsicIdentifiers.count + xGlobals.platformIdentifiers.count, xGlobals.identifierCount);
check('source-global-reference-partition', xGlobals.ecmascriptIntrinsicIdentifiers.references + xGlobals.platformIdentifiers.references, xGlobals.referenceCount);
check('source-intrinsic-global-names', xGlobals.ecmascriptIntrinsicIdentifiers.names, expectedIntrinsicGlobals);
check('source-platform-global-names', xGlobals.platformIdentifiers.names, expectedPlatformGlobals);
check('source-absent-global-names', xGlobals.absentDirectGlobals, expectedAbsentGlobals);
check('source-global-name-uniqueness', new Set([...expectedIntrinsicGlobals, ...expectedPlatformGlobals]).size, xGlobals.identifierCount);
check('source-no-eval-or-function-constructor', xGlobals.codeGeneration, 'There is no eval call and no Function constructor. Reflect.decorate and descriptor helpers are emitted module wiring and receive explicit build-eliminated rows instead of a native reflection runtime.');
check('source-selected-intrinsic-counts', sourceRuntimeStyle.intrinsicOperationProfiles.selectedReferenceCounts, {
  Array: 250, Object: 638, Reflect: 618, Map: 230, Set: 176, Promise: 192,
  Math: 1099, Number: 107, String: 131, JSON: 73, RegExp: 74, Symbol: 39
});

check('source-implicit-effect-sites', g.surfaceCounts.sourceRuntimeStyle.implicitExternalEffectSites, xImplicitExternalEffects.sites);
check('source-implicit-effect-partition-sum', sum(xImplicitExternalEffects.partition), xImplicitExternalEffects.sites);
check('source-external-navigation-emitters', g.surfaceCounts.sourceRuntimeStyle.externalNavigationEmitterSites, xImplicitExternalEffects.externalNavigationEmitters.length);
check('source-markdown-media-activation', g.surfaceCounts.sourceRuntimeStyle.markdownMediaActivationSites, xImplicitExternalEffects.markdownMediaActivationSites.length);
check('source-controlled-link-state', g.surfaceCounts.sourceRuntimeStyle.controlledLinkStateSites, xImplicitExternalEffects.controlledLinkStateSites.length);
check('source-worker-object-url', g.surfaceCounts.sourceRuntimeStyle.workerObjectUrlSites, xImplicitExternalEffects.workerObjectUrlSites.length);
check('source-marked-token-src-values', g.surfaceCounts.sourceRuntimeStyle.markedTokenSrcValueSites, xImplicitExternalEffects.valueOnlyMarkedTokenSrcSites[0].lines.length);
check('source-environment-location-reads', g.surfaceCounts.sourceRuntimeStyle.environmentLocationReadSites, xImplicitExternalEffects.environmentLocationReadSites.length);
check('source-implicit-effect-partition', xImplicitExternalEffects.partition, {
  externalNavigationEmitters: 2,
  markdownMediaActivationSites: 1,
  controlledLinkStateSites: 4,
  workerObjectUrlSites: 1,
  valueOnlyMarkedTokenSrcSites: 4,
  environmentLocationReadSites: 2
});
check('source-implicit-effect-file-hashes', xImplicitExternalEffects.sourceFiles, [
  { file: 'esm/vs/nls.js', sha256: '3b10738753e95a8561148d23f8a2deca339ad18b3d65ab6373118b79b7ed8e59' },
  { file: 'esm/vs/editor/browser/services/openerService.js', sha256: '6fef9bf593c269a766609530bb89dd32d821280985d04065c9c289b3e056ef1c' },
  { file: 'esm/vs/editor/contrib/gotoError/browser/gotoErrorWidget.js', sha256: '1c85515a6ee165ba3ed698a01a0b250c0affcd0275e933c2df4be27e3e5e7c84' },
  { file: 'esm/vs/editor/contrib/hover/browser/markerHoverParticipant.js', sha256: '6fb5f680a12c2d34203161a366db345c904b595f2716fc43eeeb5915f0f2da23' },
  { file: 'esm/vs/base/common/marked/marked.js', sha256: '75746ae6ff08f4e9b94090ed018e5ac1bf7dbb7e8fcdb4ec48784bd6569d9fda' },
  { file: 'esm/vs/platform/webWorker/browser/webWorkerServiceImpl.js', sha256: '7d52cb02b041df9f9efcdf059a7dd263b68e57d9cb2668b23cc8a07401221513' },
  { file: 'esm/vs/base/browser/markdownRenderer.js', sha256: '84577c6fd941d9cfba07a6c5f4f5118a14b0720aca1baa2c942e1787a8e39317' },
  { file: 'esm/vs/base/browser/dom.js', sha256: '030a408afb6bc698197bfe2711d21916b57c6ec67b882d9e4f6312d5e9f7a872' }
]);
check('source-no-fetch-does-not-prove-no-effects', xImplicitExternalEffects.rule.includes('absence of Fetch-like globals is not used as proof of zero external effects'), true);
check('source-uri-css-call-sites', g.surfaceCounts.sourceRuntimeStyle.asCssUrlCallSites, xUriVisualAssets.asCSSUrlCallSites);
check('source-uri-visual-producers', g.surfaceCounts.sourceRuntimeStyle.retainedUriBackedVisualProducerPaths, xUriVisualAssets.retainedUriBackedProducerPaths);
check('source-uri-visual-files', xUriVisualAssets.sourceFiles, xUriVisualAssets.files.length);
check('source-uri-visual-file-hashes', xUriVisualAssets.files, [
  { file: 'esm/vs/platform/quickinput/browser/quickInputUtils.js', lines: [30, 31], sha256: '64e7615d8d8c709608f40924c75b288f52470730c61545d43cfb01a51966e2c5' },
  { file: 'esm/vs/base/browser/ui/iconLabel/iconLabel.js', lines: [113], sha256: '6ea485663b980623c0dd3292fb5761ee9ccffc593090a7347fe21f85c1264f49' },
  { file: 'esm/vs/platform/actions/browser/menuEntryActionViewItem.js', lines: [230, 305], callSites: 4, sha256: '82ebcef6d8306d74cfc9f1709073dbd3f616151dd7ea91aad2052ecb2056e026' },
  { file: 'esm/vs/platform/quickinput/browser/quickInputList.js', lines: [359], sha256: 'a787476a8e37dd25e7a35ce2b627895b2d56662c9109094bbbd3f41ee92f3f87' },
  { file: 'esm/vs/platform/quickinput/browser/tree/quickInputTreeRenderer.js', lines: [118], sha256: 'a3d132217f3ec080f4c7e3b3a72c49803bad9617c0656e7c766c5b7431bce02e' },
  { file: 'esm/vs/platform/theme/browser/iconsStyleSheet.js', lines: [50], sha256: '204c62223fb08844574862c71cefa48083832aa7e38633ab0cc4936579899940' }
]);
check('source-uri-no-eighth-host-group', xUriVisualAssets.disposition.includes('No eighth resource-loader host group is added'), true);

check('source-clock-total-sites', xClock.stopWatchConstructionSites.total, 21);
check('source-clock-site-partition', xClock.stopWatchConstructionSites.retainedHighResolution + xClock.stopWatchConstructionSites.retainedWallClock + xClock.stopWatchConstructionSites.cutTreeSitterHighResolution, xClock.stopWatchConstructionSites.total);
check('source-clock-high-resolution-sites', xClock.stopWatchConstructionSites.retainedHighResolution, 13);
check('source-clock-wall-sites', xClock.stopWatchConstructionSites.retainedWallClock, 6);
check('source-input-latency-total', xClock.inputLatencyPerformanceCalls.total, 25);
check('source-input-latency-partition', xClock.inputLatencyPerformanceCalls.mark + xClock.inputLatencyPerformanceCalls.measure + xClock.inputLatencyPerformanceCalls.getEntriesByName + xClock.inputLatencyPerformanceCalls.clearMarks + xClock.inputLatencyPerformanceCalls.clearMeasures, xClock.inputLatencyPerformanceCalls.total);
check('source-high-resolution-domain', xClock.highResolutionClock.includes('mach_absolute_time'), true);
check('source-chromium-time-source-sha', sourceRuntimeStyle.authorities.chromiumClock.sha256, environment.authorities.chrome.timeSource.sha256);
check('source-v8-commit', sourceRuntimeStyle.authorities.v8.gitlinkCommit, '20ad8d002c17ccc7ccfbefc6c4dcf1242fe80921');
check('source-v8-ieee754-sha', sourceRuntimeStyle.authorities.v8.ieee754Sha256, '998f6f44757e62a5774fca533101145942f362c8739a247c12a37caf9fbea53f');

check('source-decoder-constructions', xEncoding.textDecoderConstructions, 3);
check('source-encoder-constructions', xEncoding.textEncoderConstructions, 1);
check('source-encoding-inert-profiles', xEncoding.baselineInertProfiles, [
  'VSBuffer.toString UTF-8 decoder because the fixed 956-module graph has no call site',
  'hashAsync TextEncoder plus crypto.subtle SHA-1 because the fixed graph has no hashAsync call site'
]);
check('source-decoder-vectors', xEncoding.chromeVectors.utf16Decoder, [
  { input: ['d800'], output: ['fffd'] },
  { input: ['dc00'], output: ['fffd'] },
  { input: ['d83d', 'dca9'], output: ['d83d', 'dca9'] },
  { input: ['dca9', 'd83d'], output: ['fffd', 'fffd'] },
  { input: ['feff'], output: [] },
  { input: ['fffe'], output: ['fffe'] }
]);
check('source-sha1-vectors', xEncoding.chromeVectors.stringSha1, [
  { input: [], output: 'da39a3ee5e6b4b0d3255bfef95601890afd80709' },
  { input: ['d800'], output: '9bdb77276c1852e1fb067820472812fcf6084024' },
  { input: ['d83d', 'dca9'], output: '82ab1e5bf66129bdbb3d5477dfe48bfcb2545cbd' },
  { input: ['dca9', 'd83d'], output: '8750ec9ddfe293cd1dc39b4245c21c270f8f52b7' },
  { input: ['feff', '0041'], output: '3a61e1ebace0447cb4a49ceb642e627cf3643b3e' }
]);
check('source-split-surrogate-sha1', xEncoding.chromeVectors.splitSurrogateSha1.includes('82ab1e5bf66129bdbb3d5477dfe48bfcb2545cbd'), true);

check('source-package-style-files', g.surfaceCounts.sourceRuntimeStyle.packageStyleFiles, xModules.packageStyleFiles);
check('source-unreachable-style-files', g.surfaceCounts.sourceRuntimeStyle.unreachableStyleFiles, xModules.unreachableStyleFiles.length);
check('source-style-package-partition', xStyles.importedStyleSheets + xModules.unreachableStyleFiles.length, xModules.packageStyleFiles);
check('source-style-sheets', xStyles.importedStyleSheets, xScan.reachableStyleResources);
check('source-style-bytes', g.surfaceCounts.sourceRuntimeStyle.styleBytes, xStyleSyntax.sourceBytes);
check('source-style-parse-zero', xStyleSyntax.parseErrors, 0);
check('source-style-validation-error-zero', xStyleSyntax.validationErrors, 0);
check('source-style-validation-warning-zero', xStyleSyntax.validationWarnings, 0);
check('source-style-rule-nodes', g.surfaceCounts.sourceRuntimeStyle.styleRuleNodes, xStyleSyntax.ruleNodes);
check('source-style-selector-texts', g.surfaceCounts.sourceRuntimeStyle.uniqueStyleSelectorTexts, xStyleSyntax.uniqueSelectorTexts);
check('source-style-nested-rules', g.surfaceCounts.sourceRuntimeStyle.nestedStyleRuleNodes, xStyleSyntax.nestedRuleNodes);
check('source-style-declarations', g.surfaceCounts.sourceRuntimeStyle.styleDeclarations, xStyleSyntax.declarations);
check('source-style-property-names', g.surfaceCounts.sourceRuntimeStyle.stylePropertyNames, xStyleSyntax.propertyNames);
check('source-style-important', g.surfaceCounts.sourceRuntimeStyle.importantStyleDeclarations, xStyleSyntax.importantDeclarations);
check('source-style-custom-properties', g.surfaceCounts.sourceRuntimeStyle.customPropertyDeclarations, xStyleSyntax.customPropertyDeclarations);
check('source-style-atrule-partition', xStyleSyntax.fontFaceRules + xStyleSyntax.keyframeRules, xStyleSyntax.atRules);
check('source-style-no-media', xStyleSyntax.mediaQueries, 0);
check('source-style-no-supports', xStyleSyntax.supportsQueries, 0);
check('source-style-keyframes', g.surfaceCounts.sourceRuntimeStyle.styleKeyframeRules, xStyleSyntax.keyframeRules);
check('source-style-keyframe-names', xStyleSyntax.keyframeNames, [
  'codicon-spin', 'fadeIn', 'fadeOut', 'fadein', 'monaco-cursor-expand', 'monaco-cursor-phase',
  'monaco-cursor-smooth', 'monaco-findInput-highlight-0', 'monaco-findInput-highlight-1',
  'monaco-findInput-highlight-dark-0', 'monaco-findInput-highlight-dark-1', 'progress'
]);
check('source-style-motion', g.surfaceCounts.sourceRuntimeStyle.styleMotionDeclarations, xStyleSyntax.motionDeclarations);
check('source-style-motion-partition', xStyleSyntax.animationFamilyDeclarations + xStyleSyntax.transitionFamilyDeclarations, xStyleSyntax.motionDeclarations);
check('source-style-variable-names', g.surfaceCounts.sourceRuntimeStyle.styleVariableNames, xStyleVariables.referencedVariableNames);
check('source-style-variable-refs', g.surfaceCounts.sourceRuntimeStyle.styleVariableReferences, xStyleVariables.variableReferences);
check('source-style-theme-variables', g.surfaceCounts.sourceRuntimeStyle.registeredThemeStyleVariables, xStyleVariables.registeredThemeColorVariableNames);
check('source-style-source-only-variables', g.surfaceCounts.sourceRuntimeStyle.sourceOnlyStyleVariables, xStyleVariables.sourceDeclaredNonThemeVariableNames);
check('source-style-dynamic-variables', g.surfaceCounts.sourceRuntimeStyle.dynamicStyleVariables, xStyleVariables.dynamicProviderVariableNames.length);
check('source-style-fallback-variables', g.surfaceCounts.sourceRuntimeStyle.fallbackOnlyStyleVariables, xStyleVariables.fallbackOnlyVariableNames.length);
check('source-style-unprovided-variables', g.surfaceCounts.sourceRuntimeStyle.fixedUnprovidedStyleVariables, xStyleVariables.fixedStandaloneUnprovidedVariableNames.length);
check('source-style-inactive-declarations', g.surfaceCounts.sourceRuntimeStyle.fixedInactiveStyleDeclarations, xStyleVariables.fixedStandaloneInactiveDeclarations);
check('source-style-variable-name-partition', xStyleVariables.registeredThemeColorVariableNames + xStyleVariables.sourceDeclaredNonThemeVariableNames + xStyleVariables.initiallyUnresolvedVariableNames, xStyleVariables.referencedVariableNames);
check('source-style-unresolved-name-partition', xStyleVariables.dynamicProviderVariableNames.length + xStyleVariables.fallbackOnlyVariableNames.length + xStyleVariables.fixedStandaloneUnprovidedVariableNames.length, xStyleVariables.initiallyUnresolvedVariableNames);
check('source-style-unresolved-ref-partition', xStyleVariables.dynamicProviderReferences + xStyleVariables.fallbackOnlyReferences + xStyleVariables.fixedStandaloneUnprovidedReferences, xStyleVariables.initiallyUnresolvedReferences);
check('source-style-all-ref-partition', xStyleVariables.registeredThemeColorReferences + xStyleVariables.sourceDeclaredNonThemeReferences + xStyleVariables.initiallyUnresolvedReferences, xStyleVariables.variableReferences);
check('source-style-dynamic-variable-names', xStyleVariables.dynamicProviderVariableNames, [
  '--animation-opacity', '--monaco-editor-warning-decoration', '--separator-border',
  '--vscode-editorCodeLens-fontFamily', '--vscode-editorCodeLens-fontFamilyDefault',
  '--vscode-editorCodeLens-fontFeatureSettings', '--vscode-editorCodeLens-fontSize',
  '--vscode-editorCodeLens-lineHeight', '--vscode-editorStickyScroll-foldingOpacityTransition',
  '--vscode-editorStickyScroll-scrollableWidth', '--vscode-hover-maxWidth', '--vscode-hover-sourceWhiteSpace',
  '--vscode-hover-whiteSpace', '--vscode-icon-x-content', '--vscode-icon-x-font-family',
  '--vscode-parameterHintsWidget-editorFontFamily', '--vscode-parameterHintsWidget-editorFontFamilyDefault',
  '--vscode-toolbar-action-min-width'
]);
check('source-style-fallback-variable-names', xStyleVariables.fallbackOnlyVariableNames, ['--vscode-codiconFontSize', '--vscode-codiconFontSize-compact']);
check('source-style-unprovided-variable-names', xStyleVariables.fixedStandaloneUnprovidedVariableNames, [
  '--text-link-decoration', '--vscode-banner-background', '--vscode-banner-foreground',
  '--vscode-banner-iconForeground', '--vscode-bodyFontSize-xSmall', '--vscode-chat-requestBubbleBackground',
  '--vscode-cornerRadius-large', '--vscode-cornerRadius-medium', '--vscode-cornerRadius-small',
  '--vscode-cornerRadius-xLarge', '--vscode-editorGutter-itemBackground', '--vscode-editorGutter-itemGlyphForeground',
  '--vscode-shadow-lg', '--vscode-shadow-md', '--vscode-shadow-xl', '--vscode-sideBar-background',
  '--vscode-sideBarSectionHeader-border'
]);
check('source-style-provider-file-hashes', xStyles.styleVariableProviderFiles, [
  { file: 'esm/vs/platform/theme/common/colorUtils.js', sha256: '600b3cf755ab09ec2b219559ae3f6e8a00a53670adeb45c3cd76fb8b52892ad3' },
  { file: 'esm/vs/platform/theme/browser/iconsStyleSheet.js', sha256: '204c62223fb08844574862c71cefa48083832aa7e38633ab0cc4936579899940' },
  { file: 'esm/vs/editor/browser/widget/codeEditor/codeEditorWidget.js', sha256: '38a9fdb9eae33533b98aa9400a9a73c347551bb74fee0184b69a374cb3f7bca0' },
  { file: 'esm/vs/base/browser/ui/splitview/splitview.js', sha256: 'a3dc4b05994889786b92305f154d17555ab057df095e59ff7623b8be7e49ab05' },
  { file: 'esm/vs/base/browser/ui/toolbar/toolbar.js', sha256: '998cd66e504183813c90cfa54edda882d45db05ec6793139cb67e8d924469927' },
  { file: 'esm/vs/editor/contrib/codelens/browser/codelensController.js', sha256: '6e8424dfb8d77c661540ad395d435298867238cc19b3b2cb13a84003d1dcd97a' },
  { file: 'esm/vs/editor/contrib/parameterHints/browser/parameterHintsWidget.js', sha256: 'a5433e4bf5945b8b90aca2bcc1d64c55e045ce3275ad873e00502c2f7482cef0' },
  { file: 'esm/vs/editor/contrib/hover/browser/contentHoverWidget.js', sha256: '083c0421d25987e3298dfc7943589ddbb89dca270b6d08053b115466d4f71f1c' },
  { file: 'esm/vs/editor/contrib/stickyScroll/browser/stickyScrollWidget.js', sha256: '7bcc5457477e7e65ff6545316741a8f12f1fa4ece043eabc542834d3e86760a6' },
  { file: 'esm/vs/editor/contrib/inlineCompletions/browser/model/inlineCompletionsModel.js', sha256: '9d2a1e447d4ecdf6f99b06171da85af6afc18d64a728dd7195821e6fcb537d76' }
]);
check('source-runtime-visual-sites', g.surfaceCounts.sourceRuntimeStyle.targetedVisualMutationSites, xRuntimeVisual.sites);
check('source-runtime-visual-files', g.surfaceCounts.sourceRuntimeStyle.targetedVisualMutationFiles, xRuntimeVisual.files);
check('source-runtime-visual-row-hash', xRuntimeVisual.rowSetSha256, 'b2b36a480c3c3eae1ca86d401ae01bcf4d1a2963dd0329e5155b0baaba598600');
check('source-runtime-visual-category-sum', Object.values(xRuntimeVisual.categories).reduce((total, item) => total + item.sites, 0), xRuntimeVisual.sites);
const xDynamicRules = xRuntimeVisual.categories.dynamicRuleOrRegistry;
check('source-runtime-rule-registry-sites', g.surfaceCounts.sourceRuntimeStyle.runtimeRuleOrRegistrySites, xDynamicRules.sites);
check('source-runtime-rule-registry-operations', xDynamicRules.operations, {
  addRule: 53, createCSSRule: 4, createStyleSheet: 13, deleteRule: 1, insertRule: 2,
  registerColor: 432, registerIcon: 37, registerThemingParticipant: 14
});
check('source-runtime-rule-registry-operation-sum', sum(xDynamicRules.operations), xDynamicRules.sites);
check('source-runtime-rule-construction-sites', g.surfaceCounts.sourceRuntimeStyle.runtimeRuleConstructionSites,
  xDynamicRules.operations.addRule + xDynamicRules.operations.createCSSRule + xDynamicRules.operations.createStyleSheet + xDynamicRules.operations.deleteRule + xDynamicRules.operations.insertRule);
check('source-runtime-theme-participants', g.surfaceCounts.sourceRuntimeStyle.themingParticipantRegistrations, xDynamicRules.operations.registerThemingParticipant);
check('source-runtime-register-color-call-sites', g.surfaceCounts.sourceRuntimeStyle.registerColorCallSites, xDynamicRules.operations.registerColor);
check('source-runtime-register-color-literals', g.surfaceCounts.sourceRuntimeStyle.registerColorLiteralIdentitySites, xDynamicRules.argumentProfiles.registerColorLiteralIdentitySites);
check('source-runtime-register-color-forwarder', g.surfaceCounts.sourceRuntimeStyle.registerColorForwarderSites, xDynamicRules.argumentProfiles.registerColorForwarderSites);
check('source-runtime-register-color-partition', xDynamicRules.argumentProfiles.registerColorLiteralIdentitySites + xDynamicRules.argumentProfiles.registerColorForwarderSites, xDynamicRules.operations.registerColor);
check('source-runtime-register-color-registry-crosscheck', xDynamicRules.argumentProfiles.registerColorLiteralIdentitySites, g.surfaceCounts.theme.colors);
check('source-runtime-register-icon-call-sites', g.surfaceCounts.sourceRuntimeStyle.registerIconCallSites, xDynamicRules.operations.registerIcon);
check('source-runtime-register-icon-literals', g.surfaceCounts.sourceRuntimeStyle.registerIconLiteralIdentitySites, xDynamicRules.argumentProfiles.registerIconLiteralIdentitySites);
check('source-runtime-register-icon-helpers', g.surfaceCounts.sourceRuntimeStyle.registerIconHelperSites, xDynamicRules.argumentProfiles.registerIconHelperSites);
check('source-runtime-register-icon-partition', xDynamicRules.argumentProfiles.registerIconLiteralIdentitySites + xDynamicRules.argumentProfiles.registerIconHelperSites, xDynamicRules.operations.registerIcon);
check('source-runtime-inline-style-sites', g.surfaceCounts.sourceRuntimeStyle.inlineStyleAssignments, xRuntimeVisual.categories.styleAssignment.sites);
check('source-runtime-style-property-sites', g.surfaceCounts.sourceRuntimeStyle.stylePropertyCalls, xRuntimeVisual.categories.stylePropertyCall.sites);
check('source-runtime-style-property-operations', xRuntimeVisual.categories.stylePropertyCall.operations, { removeProperty: 4, setProperty: 24 });
check('source-runtime-class-list-sites', g.surfaceCounts.sourceRuntimeStyle.classListCalls, xRuntimeVisual.categories.classListCall.sites);
check('source-runtime-class-list-operations', xRuntimeVisual.categories.classListCall.operations, { add: 203, remove: 93, toggle: 113 });
check('source-runtime-content-class-sites', g.surfaceCounts.sourceRuntimeStyle.contentOrClassAssignments, xRuntimeVisual.categories.contentOrClassAssignment.sites);
check('source-runtime-content-class-operations', xRuntimeVisual.categories.contentOrClassAssignment.operations, { classNamePlusEquals: 5, classNameEquals: 126, innerHTMLEquals: 10, innerTextEquals: 35, textContentEquals: 111 });
check('source-runtime-attribute-sites', g.surfaceCounts.sourceRuntimeStyle.attributeCalls, xRuntimeVisual.categories.attributeCall.sites);
check('source-runtime-attribute-operations', xRuntimeVisual.categories.attributeCall.operations, { removeAttribute: 43, setAttribute: 281, setAttributeNS: 1, toggleAttribute: 1 });
check('source-runtime-tree-sites', g.surfaceCounts.sourceRuntimeStyle.treeCallSyntacticSites, xRuntimeVisual.categories.treeCallSyntactic.sites);
check('source-runtime-tree-operations', xRuntimeVisual.categories.treeCallSyntactic.operations, { append: 228, appendChild: 302, insertAdjacentHTML: 3, insertBefore: 12, prepend: 11, remove: 191, removeChild: 7, replaceChild: 2, replaceChildren: 10, replaceWith: 3 });
check('source-runtime-overlay-not-closure', xRuntimeVisual.closureRule.includes('not the definition of all observable behavior'), true);
check('source-closed-world-rule', sourceRuntimeStyle.moduleAndResourceClosure.closedWorldDispositionRule.includes('cannot introduce a new cut, no-op, fallback, native adaptation, later target or implementation discretion'), true);
check('source-style-at-imports', xStyles.atImports, 0);
check('source-style-url-refs', g.surfaceCounts.sourceRuntimeStyle.styleUrlReferences, xStyles.urlReferences);
check('source-style-external-urls', g.surfaceCounts.sourceRuntimeStyle.externalStyleUrls, xStyles.externalUrlReferences);
check('source-style-data-urls', g.surfaceCounts.sourceRuntimeStyle.embeddedStyleDataUrls, xStyles.embeddedDataUrls);
check('source-style-font-face', g.surfaceCounts.sourceRuntimeStyle.styleFontFaceRules, xStyles.fontFaceRules);
check('source-codicon-bytes', xStyles.codiconFont.bytes, 140956);
check('source-codicon-sha', xStyles.codiconFont.sha256, 'cc2472e239e17062e7760af87f8f5997720cc0d94aa014a615c418baaf6333a8');
check('source-codicon-authority-sha', xStyles.codiconFont.sha256, g.authorityArtifacts.find(item => item.id === 'vscode-codicons').bundledFontSha256);
const sourceCandidate = g.candidateGeneratedArtifacts.find(item => item.file === sourceRuntimeStyle.candidateArtifact.file);
check('source-candidate-exists', Boolean(sourceCandidate), true);
if (sourceCandidate) check('source-candidate-contract', sourceCandidate, sourceRuntimeStyle.candidateArtifact);
check('source-candidate-row-zero', g.surfaceCounts.sourceRuntimeStyle.candidateManifestRowsClassified, 0);
check('source-native-rows-zero', sourceRuntimeStyle.implementationStatus.nativeSourceRows, 0);
check('source-js-classified-zero', sourceRuntimeStyle.implementationStatus.classifiedJavaScriptModules, 0);
check('source-unreachable-package-classified-zero', sourceRuntimeStyle.implementationStatus.classifiedUnreachablePackageJavaScriptRows, 0);
check('source-style-classified-zero', sourceRuntimeStyle.implementationStatus.classifiedStyleResources, 0);
check('source-global-classified-zero', sourceRuntimeStyle.implementationStatus.classifiedGlobalReferences, 0);
check('source-runtime-visual-classified-zero', sourceRuntimeStyle.implementationStatus.classifiedRuntimeVisualMutationRows, 0);
check('source-candidate-present-false', sourceRuntimeStyle.implementationStatus.candidateManifestPresent, false);
check('source-not-passed', sourceRuntimeStyle.implementationStatus.verdict, 'not-passed');

const expectedSnippetVariables = [
  'BLOCK_COMMENT_END', 'BLOCK_COMMENT_START', 'CLIPBOARD', 'CURRENT_DATE', 'CURRENT_DAY_NAME',
  'CURRENT_DAY_NAME_SHORT', 'CURRENT_HOUR', 'CURRENT_MILLISECONDS_UNIX', 'CURRENT_MILLISECOND',
  'CURRENT_MINUTE', 'CURRENT_MONTH', 'CURRENT_MONTH_NAME', 'CURRENT_MONTH_NAME_SHORT', 'CURRENT_SECOND',
  'CURRENT_SECONDS_UNIX', 'CURRENT_TIMEZONE_NAME', 'CURRENT_TIMEZONE_OFFSET', 'CURRENT_YEAR',
  'CURRENT_YEAR_SHORT', 'CURSOR_INDEX', 'CURSOR_NUMBER', 'LINE_COMMENT', 'RANDOM', 'RANDOM_HEX',
  'RELATIVE_FILEPATH', 'SELECTION', 'TM_CURRENT_LINE', 'TM_CURRENT_WORD', 'TM_DIRECTORY',
  'TM_DIRECTORY_BASE', 'TM_FILENAME', 'TM_FILENAME_BASE', 'TM_FILEPATH', 'TM_LINE_INDEX',
  'TM_LINE_NUMBER', 'TM_SELECTED_TEXT', 'UUID', 'WORKSPACE_FOLDER', 'WORKSPACE_NAME'
].sort();
const snippetVariables = Object.values(snippet.knownVariables.groups).flat();
check('snippet-variable-count', g.surfaceCounts.snippetEngine.knownVariables, snippet.knownVariables.count);
check('snippet-variable-groups', sum(snippet.knownVariables.groupCounts), snippet.knownVariables.count);
check('snippet-variable-array', snippetVariables.length, snippet.knownVariables.count);
check('snippet-variable-identities', [...snippetVariables].sort(), expectedSnippetVariables);
check('snippet-variable-unique', new Set(snippetVariables).size, snippetVariables.length);
check('snippet-class-count', g.surfaceCounts.snippetEngine.exportedClasses, snippet.engineSurface.exportedClasses.length);
check('snippet-token-count', g.surfaceCounts.snippetEngine.tokenTypes, snippet.engineSurface.tokenTypes.length);
check('snippet-token-ids', snippet.engineSurface.tokenTypes.map(item => item.id), Array.from({ length: 15 }, (_, index) => index));
check('snippet-resolver-count', g.surfaceCounts.snippetEngine.resolverPositions, snippet.knownVariables.resolverOrder.length);
check('snippet-resolver-order', snippet.knownVariables.resolverOrder, [
  'ModelBasedVariableResolver', 'ClipboardBasedVariableResolver', 'SelectionBasedVariableResolver',
  'CommentBasedVariableResolver', 'TimeBasedVariableResolver', 'WorkspaceBasedVariableResolver',
  'RandomBasedVariableResolver'
]);
check('snippet-format-count', g.surfaceCounts.snippetEngine.formatShorthands, snippet.grammar.formatShorthands.length);
check('snippet-formats', snippet.grammar.formatShorthands, ['upcase', 'downcase', 'capitalize', 'pascalcase', 'camelcase', 'kebabcase', 'snakecase']);
check('snippet-command-count', g.surfaceCounts.snippetEngine.commands, snippet.sessionContract.commands.length);
check('snippet-commands', snippet.sessionContract.commands, ['jumpToNextSnippetPlaceholder', 'jumpToPrevSnippetPlaceholder', 'leaveSnippet', 'acceptSnippet']);
check('snippet-catalog-zero', g.surfaceCounts.snippetEngine.bundledCatalogs, 0);
check('snippet-source-zero', snippet.implementationStatus.nativeSnippetSourceFiles, 0);
check('snippet-not-passed', snippet.implementationStatus.verdict, 'not-passed');

const expectedDiffAlgorithms = ['legacy', 'advanced', 'advanced-external', 'advanced-wasm'];
check('diff-public-values', diff.publicSurface.diffAlgorithmValues, expectedDiffAlgorithms);
check('diff-public-count', g.surfaceCounts.diffEngine.publicAlgorithmValues, diff.publicSurface.diffAlgorithmValues.length);
check('diff-disposition-count', diff.algorithmDisposition.length, diff.publicSurface.diffAlgorithmValues.length);
check('diff-disposition-values', diff.algorithmDisposition.map(item => item.value), expectedDiffAlgorithms);
check('diff-functional-count', g.surfaceCounts.diffEngine.functionalAlgorithms, diff.algorithmDisposition.filter(item => item.status === 'retained-functional').length);
check('diff-unavailable-count', g.surfaceCounts.diffEngine.fixedBaselineUnavailableAlgorithms, diff.algorithmDisposition.filter(item => item.status === 'retained-enum-fixed-baseline-unavailable').length);
check('diff-line-threshold', g.surfaceCounts.diffEngine.lineAlgorithmThreshold, Number(diff.advancedSemantics.lineAlgorithmSwitch.match(/1700/)?.[0]));
check('diff-char-threshold', g.surfaceCounts.diffEngine.characterAlgorithmThreshold, Number(diff.advancedSemantics.characterAlgorithmSwitch.match(/500/)?.[0]));
check('diff-max-file-reads', g.surfaceCounts.diffEngine.maxFileSizeComputationReads, diff.optionSemantics.maxFileSize.computationReads);
check('diff-max-file-occurrences', diff.optionSemantics.maxFileSize.sourceOccurrences, 4);
check('diff-cache-maximum', g.surfaceCounts.diffEngine.processCacheMaximumEntries, diff.cacheContract.maximumEntries);
check('diff-cache-code-bound', diff.cacheContract.maximumEntries, 11);
check('diff-npm-no-external-dependency', Object.hasOwn(diff.authorities.officialNpm.declaredDependencies, '@vscode/diff'), false);
check('diff-probe-values', diff.externalAlgorithmEvidence.fixedChromeProbe.map(item => item.algorithm), expectedDiffAlgorithms);
check('diff-probe-updates', diff.externalAlgorithmEvidence.fixedChromeProbe.map(item => item.diffUpdateCount), [1, 1, 0, 0]);
check('diff-external-errors', diff.externalAlgorithmEvidence.fixedChromeProbe.slice(2).map(item => item.unhandledRejection), ['Cannot determine URI for module id!', 'Cannot determine URI for module id!']);
check('diff-source-zero', diff.implementationStatus.nativeDiffSourceFiles, 0);
check('diff-performance-zero', diff.implementationStatus.performanceCellsPassed, 0);
check('diff-not-passed', diff.implementationStatus.verdict, 'not-passed');

check('external-direct', g.surfaceCounts.nativeTypeClosure.directExternalTypes, types.machineScan.directExternalNamedTypes.count);
check('external-direct-array', types.machineScan.directExternalNamedTypes.names.length, types.machineScan.directExternalNamedTypes.count);
check('external-transitive', g.surfaceCounts.nativeTypeClosure.transitiveExternalTypes, types.machineScan.transitiveExternalNamedTypes.count);
check('external-transitive-array', types.machineScan.transitiveExternalNamedTypes.names.length, types.machineScan.transitiveExternalNamedTypes.count);
check('native-arrays', g.surfaceCounts.nativeTypeClosure.arrays, types.machineScan.arraySyntax.occurrences);
check('native-tuples', g.surfaceCounts.nativeTypeClosure.tuples, types.machineScan.tupleSyntax.occurrences);
check('native-optionals', g.surfaceCounts.nativeTypeClosure.optionalForms, types.machineScan.optionality.questionTokenOccurrences);
check('native-nullish', g.surfaceCounts.nativeTypeClosure.nullOrUndefinedForms, types.machineScan.nullAndUndefined.occurrences);
check('native-dynamic', g.surfaceCounts.nativeTypeClosure.anyOrUnknownForms, types.machineScan.dynamicTypes.occurrences);
check('native-unresolved', g.surfaceCounts.nativeTypeClosure.unresolvedTypes, types.machineScan.unresolvedDirectTypeNames + types.machineScan.unresolvedTransitiveTypeNames);

const localeIDs = ['en', 'cs', 'de', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt-br', 'ru', 'tr', 'zh-cn', 'zh-tw', 'pseudo'];
check('localization-profile-array', localization.localeProfiles.length, localization.counts.selectableProfiles);
check('localization-profile-ids', localization.localeProfiles.map(item => item.id), localeIDs);
check('localization-message-entries', localization.localeProfiles.every(item => item.entries === 2120), true);
check('localization-message-keys', g.surfaceCounts.uiLocalization.messageKeys, localization.counts.messageKeys);
check('localization-source-modules', g.surfaceCounts.uiLocalization.sourceModules, localization.counts.sourceModules);
check('localization-selectable-profiles', g.surfaceCounts.uiLocalization.selectableProfiles, localization.counts.selectableProfiles);
check('localization-packaged-locales', g.surfaceCounts.uiLocalization.packagedLocales, localization.counts.packagedLocaleProfiles);
check('localization-full-translations', g.surfaceCounts.uiLocalization.fullyTranslatedPackagedLocales, localization.counts.fullyTranslatedPackagedProfiles);
check('localization-all-fallback', g.surfaceCounts.uiLocalization.allFallbackPackagedLocales, localization.counts.allFallbackPackagedProfiles);
const ptBR = localization.localeProfiles.find(item => item.id === 'pt-br');
check('localization-pt-br-translated', ptBR.translated, 0);
check('localization-pt-br-fallback', ptBR.fallback, 2120);
check('localization-source-zero', localization.implementationStatus.nativeLocalizationSourceFiles, 0);
check('localization-not-passed', localization.implementationStatus.verdict, 'not-passed');

check('markdown-declaration-paths', g.surfaceCounts.markdown.declarationPaths, markdown.publicSurface.counts.declarationPaths);
check('markdown-input-members', g.surfaceCounts.markdown.inputMembersBeforeMD1, markdown.publicSurface.counts.inputMembersBeforeMD1);
check('markdown-retained-members', g.surfaceCounts.markdown.retainedInputMembers, markdown.publicSurface.counts.retainedInputMembers);
check('markdown-cut-members', g.surfaceCounts.markdown.cutInputMembers, markdown.publicSurface.counts.cutInputMembers);
check('markdown-member-partition', g.surfaceCounts.markdown.retainedInputMembers + g.surfaceCounts.markdown.cutInputMembers, g.surfaceCounts.markdown.inputMembersBeforeMD1);
check('markdown-consumer-fields', g.surfaceCounts.markdown.consumerDeclarationFields, markdown.publicSurface.counts.consumerDeclarationFields);
check('markdown-consumer-files', g.surfaceCounts.markdown.consumerSourceFiles, markdown.consumerSourceFiles.length);
check('markdown-support-html-cut', markdown.dispositionCorrection.explicitMemberCuts.added, ['topLevel.IMarkdownString.supportHtml']);
check('markdown-source-zero', markdown.implementationStatus.nativeMarkdownSourceFiles, 0);
check('markdown-generated-zero', markdown.implementationStatus.generatedParserArtifacts, 0);
check('markdown-not-passed', markdown.implementationStatus.verdict, 'not-passed');

const serviceDispositionCounts = Object.fromEntries([...new Set(services.serviceMatrix.map(item => item.disposition))].sort().map(disposition => [disposition, services.serviceMatrix.filter(item => item.disposition === disposition).length]));
const declaredServiceDispositionCountsRaw = { ...services.serviceDispositionCounts };
delete declaredServiceDispositionCountsRaw.total;
const declaredServiceDispositionCounts = Object.fromEntries(Object.entries(declaredServiceDispositionCountsRaw).sort(([left], [right]) => left.localeCompare(right)));
check('service-source-closure', g.surfaceCounts.standaloneServices.reachableJavaScriptFiles, services.sourceClosure.reachableJavaScriptFiles);
check('service-style-closure', g.surfaceCounts.standaloneServices.reachableStyleResources, services.sourceClosure.reachableStyleResources);
check('service-total-closure', g.surfaceCounts.standaloneServices.totalImportedFiles, services.sourceClosure.totalImportedFiles);
check('service-closure-sum', services.sourceClosure.reachableJavaScriptFiles + services.sourceClosure.reachableStyleResources, services.sourceClosure.totalImportedFiles);
check('service-default-registrations', g.surfaceCounts.standaloneServices.defaultRegistrations, services.sourceClosure.standaloneDefaultServiceRegistrations);
check('service-classified-registrations', g.surfaceCounts.standaloneServices.classifiedRegistrations, services.serviceMatrix.length);
check('service-disposition-counts', serviceDispositionCounts, declaredServiceDispositionCounts);
check('service-disposition-total', sum(serviceDispositionCounts), services.serviceDispositionCounts.total);
check('service-storage-consumers', g.surfaceCounts.standaloneServices.directStorageConsumerFiles, services.sourceClosure.directStorageConsumerFiles);
check('service-source-consumer-array', services.sourceConsumers.length, services.sourceClosure.directStorageConsumerFiles);
check('service-session-key-identities', g.surfaceCounts.standaloneServices.addressableSessionKeyIdentities, services.sessionStorage.addressableConcreteKeyIdentities);
check('service-dialog-sites', g.surfaceCounts.standaloneServices.dialogCallSites, services.dialogs.callSites.reduce((total, item) => total + item.sourceCallSiteCount, 0));
check('service-shutdown-flush', g.surfaceCounts.standaloneServices.shutdownFlushCallSites, services.sourceClosure.shutdownFlushCallSites);
check('service-split-buttons', g.surfaceCounts.standaloneServices.splitButtonRegistrations, services.sourceClosure.splitButtonRegistrations);
check('service-source-zero', services.implementationStatus.nativeServiceSourceFiles, 0);
check('service-session-source-zero', services.implementationStatus.nativeSessionStoreSourceFiles, 0);
check('service-not-passed', services.implementationStatus.verdict, 'not-passed');

check('language-definitions', g.surfaceCounts.languageContent.definitionEntriesCut, scope.counts.languageDefinitionEntries);
check('language-descriptors', g.surfaceCounts.languageContent.descriptorsTotal, scope.counts.languageDescriptors);
check('language-descriptor-partition', g.surfaceCounts.languageContent.descriptorsCut + g.surfaceCounts.languageContent.plainTextFallbackMetadataRetained, scope.counts.languageDescriptors);
check('theme-colors', g.surfaceCounts.theme.colors, scope.counts.colors);
check('theme-icons', g.surfaceCounts.theme.productIcons, scope.counts.icons);
check('theme-builtins', g.surfaceCounts.theme.builtinThemes, scope.counts.builtinThemes);
check('ax-widgets', g.surfaceCounts.accessibility.widgetContracts, ax.widgetContracts.length);
check('ax-focus', g.surfaceCounts.accessibility.focusModes, ax.focusModes.length);
check('ax-announcements', g.surfaceCounts.accessibility.announcementPatternOccurrences, ax.sourceClosureScan.lexicalOccurrences.announcementPattern);
check('ax-announcement-partition', g.surfaceCounts.accessibility.effectiveAnnouncementSites + g.surfaceCounts.accessibility.excludedAnnouncementOccurrences, ax.sourceClosureScan.lexicalOccurrences.announcementPattern);

const h1r2Types = h1r2.groups.flatMap(group => group.concreteTypes);
check('products', g.surfaceCounts.nativeEmbedding.products, h1.publicProducts.length);
check('views', g.surfaceCounts.nativeEmbedding.appKitViews, h1.appKitViews.length);
check('wrappers', g.surfaceCounts.nativeEmbedding.swiftUITypes, h1.swiftUIWrappers.length);
check('host-groups', g.surfaceCounts.nativeEmbedding.hostContractGroups, h1r2.groups.length);
check('h1-types', g.surfaceCounts.nativeEmbedding.h1DefinedTypes, h1.hostContracts.length);
check('host-concrete-types', g.surfaceCounts.nativeEmbedding.allConcreteContractTypes, h1r2Types.length);
check('host-list', g.hostContractClosure.concreteTypes, h1r2Types);
check('host-unique-types', new Set(h1r2Types).size, h1r2Types.length);
check('process-states', g.surfaceCounts.runtimeState.processGlobalClasses, h2.runtimeScope.processGlobalMainActor.length);
check('editor-states', g.surfaceCounts.runtimeState.perEditorClasses, h2.runtimeScope.perEditorMainActor.length);
check('initial-model-states', g.surfaceCounts.runtimeState.initialModelStates, h2.editorModelConstruction.cases.length);

check('correctness-gates', g.acceptance.correctnessGates, q.correctnessGates.map(item => item.id));
check('sequential-gates', g.acceptance.correctnessGates, Array.from({ length: 10 }, (_, index) => `C${String(index + 1).padStart(2, '0')}`));
check('workloads', g.performanceDecision.workloads, q.performance.workloads);
check('sequential-workloads', g.performanceDecision.workloads, Array.from({ length: 14 }, (_, index) => `P${String(index).padStart(2, '0')}`));
check('performance-baselines', g.performanceDecision.baselines.length, q.performance.baselines.length);
check('refresh-cells', g.performanceDecision.requiredRefreshCellsHz, [60, 120]);
const expectedCandidates = ['MonaNativeDeclarationManifest.json', 'MonaRegExpUnicodeManifest.json', 'MonaEnvironmentManifest.json', 'MonaSourceClosureManifest.json', 'MonaCacheManifest.json', 'MonaDistributionManifest.json', 'QEnvironmentID.json'];
check('candidate-files', g.candidateGeneratedArtifacts.map(item => item.file), expectedCandidates);
check('candidate-count', g.surfaceCounts.verification.candidateGeneratedArtifacts, expectedCandidates.length);
check('all-candidates-absent', g.candidateGeneratedArtifacts.every(item => item.status === 'absent'), true);
check('unresolved-scope', g.designClosure.unresolvedScopeDecisions, []);
check('historical-preflight-exceptions', g.designClosure.historicalPreflightExceptions, [
  {
    id: 'hash:monacode-g3r-authoritative-manifest.json:$.normativeDomains[8].layers[2]',
    historicalExpected: '628cfa1b467f5215f0c32c7d8adb4cbf7c70773309c81b630684e8c3bcc1ac9c',
    currentActual: '49514151c4c91ad862176222603fa807e91a03319453316b57c1932f04dad0a1',
    reason: 'G3 preserved the stale F1-R3 companion hash; G4 owns the corrected current hash and G3 remains read-only historical evidence'
  },
  {
    id: 'hash:monacode-g3r-authoritative-manifest.json:$.normativeDomains[11].layers[3]',
    historicalExpected: 'c38cc2da35e360176d7137142274763e9ef5069418838a7c2b2c83a5802b9e22',
    currentActual: '546396d77b8a07b4b06c27d3dcac7843aacdef1bf490703130bde4eadc7437c4',
    reason: 'G3 preserved the pre-redaction Q1-R4 hash; G4 owns the privacy-redacted current hash and G3 remains read-only historical evidence'
  }
]);
check('historical-preflight-rule', g.designClosure.historicalPreflightRule.includes('cannot mask a G4 or non-G3 error'), true);
check('product-source-zero', g.empiricalStatus.productSourceFiles, 0);
check('product-executable-zero', g.empiricalStatus.productExecutables, 0);
check('localization-resources-zero', g.empiricalStatus.generatedLocalizationResources, 0);
check('markdown-artifacts-zero', g.empiricalStatus.generatedMarkdownArtifacts, 0);
check('standalone-service-source-zero', g.empiricalStatus.nativeStandaloneServiceSourceFiles, 0);
check('environment-table-zero', g.empiricalStatus.generatedEnvironmentIntlTables, 0);
check('snippet-source-zero-global', g.empiricalStatus.nativeSnippetSourceFiles, 0);
check('diff-source-zero-global', g.empiricalStatus.nativeDiffSourceFiles, 0);
check('source-closure-row-zero-global', g.empiricalStatus.classifiedSourceClosureRows, 0);
check('source-unreachable-package-row-zero-global', g.empiricalStatus.classifiedUnreachablePackageJavaScriptRows, 0);
check('native-style-row-zero-global', g.empiricalStatus.nativeStyleRows, 0);
check('runtime-visual-row-zero-global', g.empiricalStatus.classifiedRuntimeVisualMutationRows, 0);
check('release-not-passed', g.empiricalStatus.releaseVerdict, 'not-passed');
check('stopping-public-paths', g.designClosure.stoppingCriterion.publicDeclarationPathsClassified, '555 of 555');
check('stopping-features', g.designClosure.stoppingCriterion.featureEntriesClassified, '64 of 64');
check('stopping-services', g.designClosure.stoppingCriterion.standaloneDefaultServicesClassified, '40 of 40');
check('stopping-static-external', g.designClosure.stoppingCriterion.staticExternalImports, 0);
check('stopping-runtime-dynamic', g.designClosure.stoppingCriterion.runtimeDynamicImports, '1 of 1 classified as D1 fixed-baseline unavailable');
check('stopping-unreachable-package', g.designClosure.stoppingCriterion.unreachablePackageJavaScriptRowsClassifiedByCandidate, '38 of 38 exclusion rows required at implementation; current 0');
check('stopping-runtime-visual', g.designClosure.stoppingCriterion.targetedRuntimeVisualMutationRowsClassifiedByCandidate, '3099 of 3099 required at implementation; current 0');
check('stopping-candidates', g.designClosure.stoppingCriterion.candidateArtifactsSpecified, '7 of 7; current present 0');
check('stopping-historical-preflight', g.designClosure.stoppingCriterion.historicalPreflightExceptionsMatched, '2 of 2 exact G3 exceptions; non-historical errors 0');

check('lsp-license', g.authorityArtifacts.find(item => item.id === 'lsp-3.18-snapshot').license, 'CC BY 4.0');
check('lsp-license-sha', g.authorityArtifacts.find(item => item.id === 'lsp-3.18-snapshot').licenseSha256, '9f614db80a4e62cbb744e6f00d9da221adf45c6463556cb32f81ad1f8467f188');
check('c10-lsp-attribution', g.acceptance.overlays.C10.includes('LSP specification CC BY 4.0'), true);
const chromiumIcu = g.authorityArtifacts.find(item => item.id === 'chromium-151-icu-data');
const chromeRuntime = g.authorityArtifacts.find(item => item.id === 'chrome-m0-m1-runtime');
check('chrome-runtime-tag-commit', chromeRuntime.chromiumTagCommit, sourceRuntimeStyle.authorities.chromiumClock.tagCommit);
check('chrome-runtime-v8-commit', chromeRuntime.v8SourceCommit, sourceRuntimeStyle.authorities.v8.gitlinkCommit);
check('chrome-runtime-time-source', chromeRuntime.timeSourceSha256, sourceRuntimeStyle.authorities.chromiumClock.sha256);
check('chromium-icu-version', chromiumIcu.version, environment.authorities.chrome.icuVersion);
check('chromium-icu-commit', chromiumIcu.icuCommit, environment.authorities.chrome.icuSubmoduleCommit);
check('chromium-icu-data-sha', chromiumIcu.localIcuDataSha256, environment.authorities.chrome.localIcuDataSha256);
check('chromium-icu-license-sha', chromiumIcu.licenseSha256, environment.authorities.chrome.icuLicenseSha256);
check('icu-license-profile', g.licensingProfile.chromiumIcuData.includes(environment.authorities.chrome.icuSubmoduleCommit), true);
check('c10-icu-license', g.acceptance.overlays.C10.includes('Chromium ICU license'), true);
check('c10-no-icu-runtime', g.acceptance.overlays.C10.includes('ICU code/runtime'), true);
check('c10-no-vscode-diff', g.acceptance.overlays.C10.includes('@vscode/diff'), true);
const environmentKeys = [];
function collectKeys(value, pointer = '$') {
  if (!value || typeof value !== 'object') return;
  if (Array.isArray(value)) value.forEach((item, itemIndex) => collectKeys(item, `${pointer}[${itemIndex}]`));
  else for (const [key, item] of Object.entries(value)) {
    environmentKeys.push(`${pointer}.${key}`);
    collectKeys(item, `${pointer}.${key}`);
  }
}
collectKeys(g.currentLocalEnvironment);
check('no-sensitive-environment-key', environmentKeys.filter(key => /(serial|uuid|udid)/i.test(key)), []);
check('no-uuid-value', JSON.stringify(g.currentLocalEnvironment).match(/[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/gi) ?? [], []);
const persistedUuidHits = [];
for (const name of fs.readdirSync(root).filter(name => /\.(html|json|mjs)$/.test(name)).sort()) {
  const matches = fs.readFileSync(path.join(root, name), 'utf8').match(/[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/gi) ?? [];
  for (const value of matches) persistedUuidHits.push({ file: name, value });
}
check('no-persisted-uuid-value', persistedUuidHits, []);

process.stdout.write(JSON.stringify({
  status: failures.length === 0 ? 'pass' : 'fail',
  failureCount: failures.length,
  failures,
  audited: {
    jsonFiles: cache.size,
    normativeLayers: revisions.length,
    machineArtifacts: g.machineArtifacts.length,
    verificationTools: g.verificationTools.length,
    localHashReferences: refs.length,
    publicPaths: rows.length,
    correctnessGates: g.acceptance.correctnessGates.length,
    performanceWorkloads: g.performanceDecision.workloads.length,
    candidateArtifacts: g.candidateGeneratedArtifacts.length,
    unresolvedScopeDecisions: g.designClosure.unresolvedScopeDecisions.length
  },
  g4Sha256: sha('monacode-g4r-authoritative-manifest.json')
}, null, 2) + '\n');
