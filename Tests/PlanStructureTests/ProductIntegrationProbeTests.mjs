import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import test from 'node:test';

import {
  auditProductIntegration,
} from '../../Comparators/probes/product-integration-probe.mjs';
import {
  loadContractCatalog,
} from '../../Tools/Docs/contract-catalog.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..');
const NODE = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const FROZEN_DIGEST =
  '152c63ffc32ce2a632ff2a2caa2d3ee25063a1150c6f51bb44d5405aa30a1f36';

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

const RESOLVED_PUBLIC_API = `
public func monaEditorCreateModel() async throws { modelRegistry.create() }
public func monaEditorSetModelLanguage() async throws { modelRegistry.setLanguage() }
public func monaEditorSetModelMarkers() async throws { markerService.set() }
public func monaEditorRemoveAllMarkers() async throws { markerService.removeAll() }
public func monaEditorGetModelMarkers() async throws { markerService.get() }
public func monaEditorOnDidChangeMarkers() async throws { markerService.onDidChange() }
public func monaEditorGetModel() async throws { modelRegistry.get() }
public func monaEditorGetModels() async throws { modelRegistry.getAll() }
public protocol MonaEditorICursorPositionChangedEvent { var position: MonaPosition { get } }
public protocol MonaEditorICursorSelectionChangedEvent { var selection: MonaSelection { get } }
public protocol MonaLanguagesCodeActionContext { var trigger: Int { get } }
public struct MonaLanguagesProviderResult { public let value: Any }
public protocol MonaLanguagesHoverContext { var verbosity: Int { get } }
public protocol MonaLanguagesCompletionContext { var triggerKind: Int { get } }
public protocol MonaLanguagesInlineCompletionContext { var triggerKind: Int { get } }
public protocol MonaLanguagesSignatureHelpResult { var value: Any { get } }
public protocol MonaLanguagesSignatureHelpContext { var triggerKind: Int { get } }
public protocol MonaLanguagesReferenceContext { var includeDeclaration: Bool { get } }
public protocol MonaLanguagesFoldingContext { var maxRanges: Int { get } }
`;

const RESOLVED_SOURCES = new Map([
  [PATHS.model, `
public func findMatches() { searchEngine.findMatches() }
public func findNextMatch() { searchEngine.findNextMatch() }
public func findPreviousMatch() { searchEngine.findPreviousMatch() }
public func getWordAtPosition() { wordResolver.wordAtPosition() }
public func getWordUntilPosition() { wordResolver.wordUntilPosition() }
public func deltaDecorations() { decorationStore.deltaDecorations() }
public func getDecorationOptions() { decorationStore.options() }
public func undo() { undoRedoStack.undo() }
public func canUndo() -> Bool { undoRedoStack.canUndo }
public func redo() { undoRedoStack.redo() }
public func canRedo() -> Bool { undoRedoStack.canRedo }
`],
  [PATHS.instances, `
extension MonaCodeEditorView: MonaInstanceIStandaloneCodeEditor {}
extension MonaDiffEditorView: MonaInstanceIStandaloneDiffEditor {}
`],
  [PATHS.editorView, `
private let featureRegistry = MonaFeatureRegistry()
private let contributionRegistry = MonaContributionRegistry()
internal func performAttach(model: MonaCodeModel) {
  featureRegistry.installFeatures(on: self)
  contributionRegistry.installContributions(on: self)
}
`],
  [PATHS.diffView, 'public final class MonaDiffEditorView {}'],
  [PATHS.multiDiffView, 'public final class MonaMultiDiffEditorView {}'],
  [PATHS.diffFactory, `
public func createDiffEditor() -> MonaDiffEditorView { return MonaDiffEditorView() }
public func createMultiFileDiffEditor() -> MonaMultiDiffEditorView {
  return MonaMultiDiffEditorView()
}
`],
  [PATHS.sample, `
MonaDiffEditorView()
MonaMultiDiffEditorView()
MonaDiffEditor(model: model)
MonaMultiDiffEditor(models: models)
`],
  [PATHS.publicAPI, RESOLVED_PUBLIC_API],
  [PATHS.markers, `
public final class MonaMarkerService {
  public let onDidChangeMarkers: MonaEvent<[MonaURI]>
  public func setModelMarkers() {}
  public func getModelMarkers() {}
  public func removeAllMarkers() {}
}
`],
  [PATHS.services, 'MonaMarkerService.self MonaGlobalModelRegistry.self'],
  [PATHS.modelRegistry, `
public final class MonaGlobalModelRegistry {
  public func model(for uri: MonaURI) -> MonaCodeModel? { nil }
  public func models() -> [MonaCodeModel] { [] }
  public func setLanguage(_ language: String, for uri: MonaURI) {}
}
`],
  [PATHS.appKitAPI, `
public protocol MonaEditorIViewZone { var afterLineNumber: Int { get } }
public protocol MonaEditorIContentWidget { var id: String { get } }
public protocol MonaEditorIOverlayWidget { var id: String { get } }
public protocol MonaEditorIGlyphMarginWidget { var id: String { get } }
public protocol MonaEditorIBaseMouseTarget { var type: Int { get } }
`],
  [PATHS.widgetProxy, `
public final class MonaWidgetMouseTargetController {
  public func getTargetAtClientPoint(_ point: CGPoint) -> MonaEditorIBaseMouseTarget? { nil }
}
`],
]);

const seededCases = [
  {
    id: 'MODEL_RETAINED_MEMBERS_STUBBED',
    path: PATHS.model,
    seed: `
public func findMatches() -> [MonaFindMatch] { return [] }
public func getWordAtPosition() -> MonaRange? { return nil }
public func deltaDecorations() -> [String] { return [] }
public func undo() { /* No-op until Phase 02 undo/redo. */ }
public func canUndo() -> Bool { return false }
public func redo() { /* No-op until Phase 02 undo/redo. */ }
public func canRedo() -> Bool { return false }
`,
  },
  {
    id: 'INSTANCE_SURFACE_UNCONFORMED',
    path: PATHS.instances,
    seed: 'public protocol MonaInstanceIEditor {}\npublic protocol MonaInstanceICodeEditor {}',
  },
  {
    id: 'DIFF_FACTORY_NOT_WIRED',
    path: PATHS.diffFactory,
    seed: `
public func createDiffEditor() throws { throw MonaEditorFactoryError.phase07NotWired }
public func createMultiFileDiffEditor() throws { throw MonaEditorFactoryError.phase07NotWired }
`,
  },
  {
    id: 'SAMPLE_HOST_DIFF_ACTIVATION_ABSENT',
    path: PATHS.sample,
    seed: 'MonaCodeEditorView()\nMonaCodeEditor(model: model)',
  },
  {
    id: 'MARKER_SERVICE_ABSENT',
    path: PATHS.markers,
    seed: 'public struct MonaMarker {}',
    extra: new Map([[PATHS.publicAPI, RESOLVED_PUBLIC_API.replace(
      /public func monaEditor(SetModelMarkers|RemoveAllMarkers|GetModelMarkers|OnDidChangeMarkers)\(\) async throws \{[^}]*\}/g,
      (match) => match.replace(/\{[^}]*\}/, '{}'),
    )]]),
  },
  {
    id: 'GLOBAL_MODEL_REGISTRY_ABSENT',
    path: PATHS.modelRegistry,
    seed: 'public final class MonaInitialModelRegistry {}',
    extra: new Map([[PATHS.publicAPI, RESOLVED_PUBLIC_API.replace(
      /public func monaEditor(CreateModel|SetModelLanguage|GetModel|GetModels)\(\) async throws \{[^}]*\}/g,
      (match) => match.replace(/\{[^}]*\}/, '{}'),
    )]]),
  },
  {
    id: 'CURSOR_EVENT_PAYLOADS_EMPTY',
    path: PATHS.publicAPI,
    seed: RESOLVED_PUBLIC_API
      .replace(
        /public protocol MonaEditorICursorPositionChangedEvent \{[^}]*\}/,
        'public protocol MonaEditorICursorPositionChangedEvent {}',
      )
      .replace(
        /public protocol MonaEditorICursorSelectionChangedEvent \{[^}]*\}/,
        'public protocol MonaEditorICursorSelectionChangedEvent {}',
      ),
  },
  {
    id: 'WIDGET_MOUSE_TARGET_SURFACE_EMPTY',
    path: PATHS.appKitAPI,
    seed: `
public protocol MonaEditorIViewZone {}
public protocol MonaEditorIContentWidget {}
public protocol MonaEditorIOverlayWidget {}
public protocol MonaEditorIGlyphMarginWidget {}
public protocol MonaEditorIBaseMouseTarget {}
`,
    extra: new Map([[PATHS.widgetProxy, 'public final class MonaAXWidgetProxy {}']]),
  },
  {
    id: 'LANGUAGE_CONTEXT_TYPES_EMPTY',
    path: PATHS.publicAPI,
    seed: RESOLVED_PUBLIC_API
      .replace(/public protocol MonaLanguagesCodeActionContext \{[^}]*\}/, 'public protocol MonaLanguagesCodeActionContext {}')
      .replace(/public struct MonaLanguagesProviderResult \{[^}]*\}/, 'public struct MonaLanguagesProviderResult {}')
      .replace(/public protocol MonaLanguagesHoverContext \{[^}]*\}/, 'public protocol MonaLanguagesHoverContext {}')
      .replace(/public protocol MonaLanguagesCompletionContext \{[^}]*\}/, 'public protocol MonaLanguagesCompletionContext {}')
      .replace(/public protocol MonaLanguagesInlineCompletionContext \{[^}]*\}/, 'public protocol MonaLanguagesInlineCompletionContext {}')
      .replace(/public protocol MonaLanguagesSignatureHelpResult \{[^}]*\}/, 'public protocol MonaLanguagesSignatureHelpResult {}')
      .replace(/public protocol MonaLanguagesSignatureHelpContext \{[^}]*\}/, 'public protocol MonaLanguagesSignatureHelpContext {}')
      .replace(/public protocol MonaLanguagesReferenceContext \{[^}]*\}/, 'public protocol MonaLanguagesReferenceContext {}')
      .replace(/public protocol MonaLanguagesFoldingContext \{[^}]*\}/, 'public protocol MonaLanguagesFoldingContext {}'),
  },
  {
    id: 'FEATURE_ACTIVATION_PATH_ABSENT',
    path: PATHS.editorView,
    seed: 'internal func performAttach(model: MonaCodeModel) { viewGraph = MonaViewGraph(model: model) }',
  },
];

function audit(overrides, digest = FROZEN_DIGEST, evidenceDigest = FROZEN_DIGEST) {
  return auditProductIntegration(REPO_ROOT, {
    sourceOverrides: overrides,
    verificationSourceSetDigest: digest,
    evidenceSourceSetDigest: evidenceDigest,
    catalog: loadContractCatalog(REPO_ROOT),
  });
}

test('fully resolved source signatures produce no integration findings', () => {
  assert.deepEqual(audit(RESOLVED_SOURCES).findings, []);
});

for (const fixture of seededCases) {
  test(`${fixture.id} is controlled by its concrete source signature`, () => {
    const seeded = new Map(RESOLVED_SOURCES);
    seeded.set(fixture.path, fixture.seed);
    for (const [path, text] of fixture.extra ?? []) seeded.set(path, text);

    const ids = audit(seeded).findings.map((finding) => finding.id);
    assert.equal(ids.includes(fixture.id), true, `${fixture.id} must appear for its seed`);
    assert.equal(
      audit(RESOLVED_SOURCES).findings.some((finding) => finding.id === fixture.id),
      false,
      `${fixture.id} must disappear for its resolved signature`,
    );
  });
}

test('CURRENT_RELEASE_EVIDENCE_STALE compares the two source digests directly', () => {
  assert.equal(
    audit(RESOLVED_SOURCES, FROZEN_DIGEST, FROZEN_DIGEST).findings
      .some((finding) => finding.id === 'CURRENT_RELEASE_EVIDENCE_STALE'),
    false,
  );
  assert.equal(
    audit(RESOLVED_SOURCES, '0'.repeat(64), FROZEN_DIGEST).findings
      .some((finding) => finding.id === 'CURRENT_RELEASE_EVIDENCE_STALE'),
    true,
  );
});

test('current repository findings and exact task bindings are source-backed', () => {
  const { findings } = auditProductIntegration(REPO_ROOT);
  const byID = new Map(findings.map((finding) => [finding.id, finding]));

  assert.deepEqual([...byID.keys()].sort(), [
    'CURRENT_RELEASE_EVIDENCE_STALE',
    'SAMPLE_HOST_DIFF_ACTIVATION_ABSENT',
  ]);
  assert.deepEqual(byID.get('SAMPLE_HOST_DIFF_ACTIVATION_ABSENT').taskIDs, [
    'P07-T009', 'P07-T010',
  ]);

  const phase89 = loadContractCatalog(REPO_ROOT).planTasks
    .filter((task) => task.phase === '08' || task.phase === '09')
    .map((task) => task.id)
    .sort();
  assert.equal(phase89.length, 40);
  assert.deepEqual(byID.get('CURRENT_RELEASE_EVIDENCE_STALE').taskIDs, phase89);

  for (const finding of findings) {
    assert.equal(finding.paths.length > 0, true, `${finding.id} must name source paths`);
    assert.equal(finding.observation.length > 0, true, `${finding.id} must explain the observation`);
    assert.equal(finding.unblockCondition.length > 0, true, `${finding.id} must define closure`);
  }
});

test('probe CLI emits canonical parseable JSON and exits 1 for current findings', () => {
  const result = spawnSync(
    NODE,
    ['Comparators/probes/product-integration-probe.mjs'],
    { cwd: REPO_ROOT, encoding: 'utf8' },
  );

  assert.equal(result.status, 1, result.stderr);
  const parsed = JSON.parse(result.stdout);
  assert.equal(parsed.findings.length, 2);
  assert.deepEqual(
    parsed.findings.map((finding) => finding.id),
    parsed.findings.map((finding) => finding.id).sort(),
  );
});
