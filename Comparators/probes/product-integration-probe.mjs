import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  loadContractCatalog,
} from '../../Tools/Docs/contract-catalog.mjs';
import {
  computeVerificationSourceSet,
} from '../../Tools/Docs/source-set.mjs';

export const FROZEN_RELEASE_SOURCE_SET_DIGEST =
  '152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36';

const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_REPO_ROOT = resolve(HERE, '..', '..');

const PATHS = {
  model: 'Sources/MonaCode/Model/MonaCodeModel.swift',
  instances: 'Sources/MonaCodeAppKit/Views/MonaEditorInstanceAdapters.swift',
  editorView: 'Sources/MonaCodeAppKit/Views/MonaCodeEditorView.swift',
  diffView: 'Sources/MonaCodeAppKit/Views/MonaDiffEditorView.swift',
  multiDiffView: 'Sources/MonaCodeAppKit/Views/MonaMultiDiffEditorView.swift',
  diffFactory: 'Sources/MonaCodeAppKit/Views/MonaEditorFactory.swift',
  sample: 'Sources/MonaCodeSample/main.swift',
  publicAPI: 'Sources/MonaCode/Generated/MonaPublicAPI.swift',
  markers: 'Sources/MonaCode/Base/MonaMarker.swift',
  services: 'Sources/MonaCode/Services/MonaStandaloneServices.swift',
  modelRegistry: 'Sources/MonaCode/Runtime/MonaInitialModelRegistry.swift',
  appKitAPI: 'Sources/MonaCodeAppKit/Generated/MonaAppKitPublicAPI.swift',
  widgetProxy: 'Sources/MonaCodeAppKit/Accessibility/MonaAXWidgetProxy.swift',
};

const MODEL_TASKS = ['P01-T008', 'P02-T001', 'P02-T002', 'P02-T003'];
const INSTANCE_TASKS = ['P05-T012', 'P07-T009'];
const DIFF_FACTORY_TASKS = ['P05-T112', 'P07-T009', 'P07-T010'];
const SAMPLE_TASKS = ['P07-T009', 'P07-T010'];
const MARKER_TASKS = ['P05-T001', 'P05-T012', 'P05-T122'];
const MODEL_REGISTRY_TASKS = ['P01-T012', 'P05-T012'];
const CURSOR_TASKS = ['P04-T007', 'P05-T012'];
const WIDGET_TASKS = [
  'P03-T007',
  'P05-T012',
  'P05-T104',
  'P05-T116',
  'P05-T117',
  'P05-T118',
  'P05-T125',
  'P05-T146',
  'P05-T151',
  'P05-T153',
];
const LANGUAGE_TASKS = ['P05-T001', 'P05-T013', 'P06-T005'];

const LANGUAGE_SHELLS = [
  ['protocol', 'MonaLanguagesCodeActionContext'],
  ['struct', 'MonaLanguagesProviderResult'],
  ['protocol', 'MonaLanguagesHoverContext'],
  ['protocol', 'MonaLanguagesCompletionContext'],
  ['protocol', 'MonaLanguagesInlineCompletionContext'],
  ['protocol', 'MonaLanguagesSignatureHelpResult'],
  ['protocol', 'MonaLanguagesSignatureHelpContext'],
  ['protocol', 'MonaLanguagesReferenceContext'],
  ['protocol', 'MonaLanguagesFoldingContext'],
];

const compareUTF8 = (left, right) =>
  Buffer.compare(Buffer.from(left, 'utf8'), Buffer.from(right, 'utf8'));

function normalizeOverrides(sourceOverrides) {
  if (sourceOverrides instanceof Map) return sourceOverrides;
  return new Map(Object.entries(sourceOverrides ?? {}));
}

function sourceReader(repoRoot, sourceOverrides) {
  const overrides = normalizeOverrides(sourceOverrides);
  return (path) => {
    if (overrides.has(path)) return overrides.get(path);
    const absolutePath = resolve(repoRoot, path);
    return existsSync(absolutePath) ? readFileSync(absolutePath, 'utf8') : '';
  };
}

function declarationHasMembers(text, kind, name) {
  const match = text.match(
    new RegExp(`public\\s+${kind}\\s+${name}(?:\\s*:[^{]+)?\\s*\\{([^}]*)\\}`),
  );
  return match !== null && match[1].trim().length > 0;
}

function functionHasImplementation(text, name) {
  const match = text.match(
    new RegExp(`public\\s+func\\s+${name}\\s*\\([^)]*\\)[^{]*\\{([^}]*)\\}`),
  );
  return match !== null && match[1].trim().length > 0;
}

function concreteConformance(text, protocolPattern) {
  return new RegExp(
    `(?:extension|(?:public\\s+)?(?:final\\s+)?(?:class|struct))\\s+` +
      `[_A-Za-z][_A-Za-z0-9]*(?:[^:{\\n]*)?:[^\\n{]*${protocolPattern}`,
  ).test(text);
}

function finding(id, taskIDs, paths, observation, unblockCondition) {
  return {
    id,
    taskIDs: taskIDs.slice().sort(compareUTF8),
    paths: paths.slice().sort(compareUTF8),
    observation,
    unblockCondition,
  };
}

function featureTaskIDs(catalog) {
  return catalog.planTasks
    .filter((task) => task.phase === '05')
    .filter((task) => {
      const taskNumber = Number(task.id.slice(-3));
      return taskNumber >= 100 && taskNumber <= 161;
    })
    .map((task) => task.id)
    .sort(compareUTF8);
}

function releaseTaskIDs(catalog) {
  return catalog.planTasks
    .filter((task) => task.phase === '08' || task.phase === '09')
    .map((task) => task.id)
    .sort(compareUTF8);
}

function validateTaskBindings(findings, catalog) {
  const valid = new Set(catalog.planTasks.map((task) => task.id));
  for (const row of findings) {
    for (const taskID of row.taskIDs) {
      if (!valid.has(taskID)) {
        throw new Error(`PRODUCT_PROBE_UNKNOWN_TASK ${row.id} ${taskID}`);
      }
    }
  }
}

export function auditProductIntegration(repoRoot, options = {}) {
  const catalog = options.catalog ?? loadContractCatalog(repoRoot);
  const readSource = sourceReader(repoRoot, options.sourceOverrides);
  const verificationSourceSetDigest = options.verificationSourceSetDigest
    ?? computeVerificationSourceSet(repoRoot).digest;
  const evidenceSourceSetDigest = options.evidenceSourceSetDigest
    ?? FROZEN_RELEASE_SOURCE_SET_DIGEST;

  const model = readSource(PATHS.model);
  const instances = [
    readSource(PATHS.instances),
    readSource(PATHS.editorView),
    readSource(PATHS.diffView),
    readSource(PATHS.multiDiffView),
  ].join('\n');
  const diffFactory = readSource(PATHS.diffFactory);
  const sample = readSource(PATHS.sample);
  const publicAPI = readSource(PATHS.publicAPI);
  const markerSources = [
    readSource(PATHS.markers),
    readSource(PATHS.services),
    publicAPI,
  ].join('\n');
  const modelRegistrySources = [
    readSource(PATHS.modelRegistry),
    readSource(PATHS.services),
    publicAPI,
  ].join('\n');
  const appKitAPI = readSource(PATHS.appKitAPI);
  const widgetSources = [appKitAPI, readSource(PATHS.widgetProxy)].join('\n');
  const editorView = readSource(PATHS.editorView);
  const findings = [];

  const modelForbidden = [
    /func\s+findMatches[\s\S]{0,500}\{\s*return\s+\[\]\s*\}/,
    /func\s+(?:findNextMatch|findPreviousMatch|getWordAtPosition|getWordUntilPosition)[\s\S]{0,500}\{\s*return\s+nil\s*\}/,
    /func\s+deltaDecorations[\s\S]{0,500}\{\s*return\s+\[\]\s*\}/,
    /No-op until Phase 02 undo\/redo/,
    /func\s+can(?:Undo|Redo)[\s\S]{0,120}\{\s*return\s+false\s*\}/,
  ].some((pattern) => pattern.test(model));
  const modelPositive = [
    'searchEngine',
    'wordResolver',
    'decorationStore',
    'undoRedoStack',
  ].every((token) => model.includes(token));
  if (modelForbidden || !modelPositive) {
    findings.push(finding(
      'MODEL_RETAINED_MEMBERS_STUBBED',
      MODEL_TASKS,
      [PATHS.model],
      'Retained search, word, decoration, and undo/redo model members still expose empty, nil, false, or no-op behavior.',
      'Replace every retained stub with shared search, word, decoration, and undo/redo state and pass the bound model task tests.',
    ));
  }

  const hasCodeConformance = concreteConformance(
    instances,
    'MonaInstanceI(?:Standalone)?CodeEditor',
  );
  const hasDiffConformance = concreteConformance(
    instances,
    'MonaInstanceI(?:Standalone)?DiffEditor',
  );
  if (!hasCodeConformance || !hasDiffConformance) {
    findings.push(finding(
      'INSTANCE_SURFACE_UNCONFORMED',
      INSTANCE_TASKS,
      [PATHS.instances, PATHS.editorView, PATHS.diffView, PATHS.multiDiffView],
      'The retained editor instance protocols exist, but concrete code-editor and diff-editor types do not conform to them.',
      'Add concrete code and diff instance conformances and pass the public instance-surface behavior tests.',
    ));
  }

  const diffFactoryForbidden = diffFactory.includes(
    'throw MonaEditorFactoryError.phase07NotWired',
  );
  const diffFactoryPositive =
    /return\s+MonaDiffEditorView\s*\(/.test(diffFactory)
    && /return\s+MonaMultiDiffEditorView\s*\(/.test(diffFactory);
  if (diffFactoryForbidden || !diffFactoryPositive) {
    findings.push(finding(
      'DIFF_FACTORY_NOT_WIRED',
      DIFF_FACTORY_TASKS,
      [PATHS.diffFactory],
      'createDiffEditor and createMultiFileDiffEditor still throw phase07NotWired instead of returning attached concrete views.',
      'Wire both factory methods to attached concrete diff views and pass their factory and lifecycle tests.',
    ));
  }

  const sampleTypes = [
    'MonaDiffEditorView',
    'MonaMultiDiffEditorView',
    'MonaDiffEditor',
    'MonaMultiDiffEditor',
  ];
  if (!sampleTypes.every((type) => sample.includes(type))) {
    findings.push(finding(
      'SAMPLE_HOST_DIFF_ACTIVATION_ABSENT',
      SAMPLE_TASKS,
      [PATHS.sample],
      'The sample host does not activate all four AppKit and SwiftUI diff editor products.',
      'Construct all four diff view/wrapper types in the sample activation path and pass testSampleHostActivatesThreeProducts.',
    ));
  }

  const markerPositive =
    /(?:public\s+)?final\s+class\s+MonaMarkerService/.test(markerSources)
    && markerSources.includes('onDidChangeMarkers')
    && markerSources.includes('setModelMarkers')
    && markerSources.includes('getModelMarkers')
    && markerSources.includes('removeAllMarkers')
    && [
      'monaEditorSetModelMarkers',
      'monaEditorRemoveAllMarkers',
      'monaEditorGetModelMarkers',
      'monaEditorOnDidChangeMarkers',
    ].every((name) => functionHasImplementation(publicAPI, name));
  const markerForbidden = [
    'monaEditorSetModelMarkers',
    'monaEditorRemoveAllMarkers',
    'monaEditorGetModelMarkers',
    'monaEditorOnDidChangeMarkers',
  ].some((name) => !functionHasImplementation(publicAPI, name));
  if (markerForbidden || !markerPositive) {
    findings.push(finding(
      'MARKER_SERVICE_ABSENT',
      MARKER_TASKS,
      [PATHS.markers, PATHS.services, PATHS.publicAPI],
      'Marker value types and retained declarations exist without a concrete global set/get/remove/change marker service.',
      'Implement one marker service, route the four retained public functions through it, and pass marker publication tests.',
    ));
  }

  const registryPositive =
    /(?:public\s+)?final\s+class\s+MonaGlobalModelRegistry/.test(modelRegistrySources)
    && /model\s*\(for\s+uri:/.test(modelRegistrySources)
    && /func\s+models\s*\(/.test(modelRegistrySources)
    && /setLanguage\s*\(/.test(modelRegistrySources)
    && [
      'monaEditorCreateModel',
      'monaEditorSetModelLanguage',
      'monaEditorGetModel',
      'monaEditorGetModels',
    ].every((name) => functionHasImplementation(publicAPI, name));
  const registryForbidden = [
    'monaEditorCreateModel',
    'monaEditorSetModelLanguage',
    'monaEditorGetModel',
    'monaEditorGetModels',
  ].some((name) => !functionHasImplementation(publicAPI, name));
  if (registryForbidden || !registryPositive) {
    findings.push(finding(
      'GLOBAL_MODEL_REGISTRY_ABSENT',
      MODEL_REGISTRY_TASKS,
      [PATHS.modelRegistry, PATHS.services, PATHS.publicAPI],
      'The retained create/get/list/language functions are empty and no URI-keyed global model registry owns them.',
      'Implement one URI-keyed global model registry, route all retained model functions through it, and pass lifecycle tests.',
    ));
  }

  const cursorPositive =
    declarationHasMembers(publicAPI, 'protocol', 'MonaEditorICursorPositionChangedEvent')
    && declarationHasMembers(publicAPI, 'protocol', 'MonaEditorICursorSelectionChangedEvent');
  const cursorForbidden =
    /public\s+protocol\s+MonaEditorICursorPositionChangedEvent\s*\{\s*\}/.test(publicAPI)
    || /public\s+protocol\s+MonaEditorICursorSelectionChangedEvent\s*\{\s*\}/.test(publicAPI);
  if (cursorForbidden || !cursorPositive) {
    findings.push(finding(
      'CURSOR_EVENT_PAYLOADS_EMPTY',
      CURSOR_TASKS,
      [PATHS.publicAPI, PATHS.instances],
      'Cursor position and selection event protocols are zero-member shells despite being exposed by editor instances.',
      'Define concrete position, selection, reason, source, and secondary-position payloads and publish them from editor state.',
    ));
  }

  const widgetDeclarations = [
    'MonaEditorIViewZone',
    'MonaEditorIContentWidget',
    'MonaEditorIOverlayWidget',
    'MonaEditorIGlyphMarginWidget',
    'MonaEditorIBaseMouseTarget',
  ];
  const widgetPositive = widgetDeclarations.every(
    (name) => declarationHasMembers(appKitAPI, 'protocol', name),
  )
    && /(?:public\s+)?final\s+class\s+MonaWidgetMouseTargetController/.test(widgetSources)
    && widgetSources.includes('getTargetAtClientPoint');
  const widgetForbidden = widgetDeclarations.some((name) =>
    new RegExp(`public\\s+protocol\\s+${name}\\s*\\{\\s*\\}`).test(appKitAPI));
  if (widgetForbidden || !widgetPositive) {
    findings.push(finding(
      'WIDGET_MOUSE_TARGET_SURFACE_EMPTY',
      WIDGET_TASKS,
      [PATHS.appKitAPI, PATHS.widgetProxy],
      'View-zone, content/overlay/glyph widget, and base mouse-target declarations lack concrete payloads and a hit-test controller path.',
      'Implement the retained widget payloads, lifecycle controller, and mouse-target hit testing, then pass dependent feature tests.',
    ));
  }

  const languagePositive = LANGUAGE_SHELLS.every(([kind, name]) =>
    declarationHasMembers(publicAPI, kind, name));
  const languageForbidden = LANGUAGE_SHELLS.some(([kind, name]) =>
    new RegExp(`public\\s+${kind}\\s+${name}\\s*\\{\\s*\\}`).test(publicAPI));
  if (languageForbidden || !languagePositive) {
    findings.push(finding(
      'LANGUAGE_CONTEXT_TYPES_EMPTY',
      LANGUAGE_TASKS,
      [PATHS.publicAPI],
      'Retained provider context and result declarations remain zero-member shells and cannot carry Monaco-equivalent request metadata.',
      'Populate every retained context/result declaration and bind direct-provider and LSP adapters to those exact payloads.',
    ));
  }

  const featureActivationPositive =
    /(?:private|internal|public)\s+let\s+[_A-Za-z][_A-Za-z0-9]*\s*=\s*MonaFeatureRegistry\s*\(/.test(editorView)
    && /(?:private|internal|public)\s+let\s+[_A-Za-z][_A-Za-z0-9]*\s*=\s*MonaContributionRegistry\s*\(/.test(editorView)
    && editorView.includes('installFeatures')
    && editorView.includes('installContributions');
  const featureActivationForbidden = editorView.includes('performAttach')
    && !featureActivationPositive;
  if (featureActivationForbidden || !featureActivationPositive) {
    findings.push(finding(
      'FEATURE_ACTIVATION_PATH_ABSENT',
      featureTaskIDs(catalog),
      [PATHS.editorView],
      'Editor attachment builds rendering and input subsystems without installing the retained feature and contribution registries.',
      'Instantiate the registries at editor lifetime scope, install all retained identities during attachment, and pass all feature activation tests.',
    ));
  }

  if (verificationSourceSetDigest !== evidenceSourceSetDigest) {
    findings.push(finding(
      'CURRENT_RELEASE_EVIDENCE_STALE',
      releaseTaskIDs(catalog),
      ['Tools/Release/release-verdict.mjs'],
      `Current verification source digest ${verificationSourceSetDigest} differs from frozen release evidence digest ${evidenceSourceSetDigest}.`,
      'Regenerate and pass every P08/P09 current-digest release prerequisite before emitting a passed verdict.',
    ));
  }

  findings.sort((left, right) => compareUTF8(left.id, right.id));
  validateTaskBindings(findings, catalog);

  return {
    verificationSourceSetDigest,
    evidenceSourceSetDigest,
    findings,
  };
}

function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value !== null && typeof value === 'object') {
    const sorted = {};
    for (const key of Object.keys(value).sort(compareUTF8)) {
      if (value[key] !== undefined) sorted[key] = sortKeys(value[key]);
    }
    return sorted;
  }
  return value;
}

export function canonicalJSON(value, spacing = 2) {
  return `${JSON.stringify(sortKeys(value), null, spacing)}\n`;
}

const invokedDirectly = process.argv[1]
  && resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (invokedDirectly) {
  const result = auditProductIntegration(DEFAULT_REPO_ROOT);
  process.stdout.write(canonicalJSON(result));
  process.exitCode = result.findings.length === 0 ? 0 : 1;
}
