import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  auditEnvironment,
  collectEnvironment
} from '../tools/collect-environment.mjs';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const manifestPath = path.resolve(
  testDirectory,
  '../../artifacts/monacode-g5r-qualification-environment-manifest.json'
);

const loadManifest = () => JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

test('pins the exact qualified runtime and comparator provenance', () => {
  const manifest = loadManifest();
  const qualified = manifest.qualifiedEnvironment;

  assert.equal(qualified.macOS.version, '26.6.1');
  assert.equal(qualified.macOS.build, '25G76');
  assert.equal(qualified.xcode.version, '26.6');
  assert.equal(qualified.xcode.build, '17F113');
  assert.equal(qualified.macOSSDK, '26.5');
  assert.equal(qualified.swift.version, '6.3.3');
  assert.equal(qualified.architecture, 'arm64');
  assert.equal(qualified.chrome.version, '151.0.7922.138');
  assert.equal(
    qualified.chrome.binarySha256,
    'ee37661755341e9fc1babf9c20ec09d6a36e50aa8713ceb08082f8bbe2d8217d'
  );
  assert.equal(qualified.chrome.chromiumTagCommit, '41fa82442390a4d4456c78f2d69a832d5720cb27');
  assert.equal(qualified.chrome.v8.version, '15.1.206.17');
  assert.equal(qualified.chrome.v8.sourceCommit, '00c2754b59cf5f79b323950c63b07cfb1a8377d4');
  assert.equal(qualified.chrome.icu.version, '78.2');
  assert.equal(qualified.chrome.icu.sourceCommit, 'd578f2e8b7bd5938e21cfb6bf15c079e0aa5b738');
  assert.equal(
    qualified.chrome.icu.dataSha256,
    '9f48c7f9c7c94d516a14870707e910ab94d75ae640ff6842c4af53276cd26ebe'
  );
  assert.equal(
    qualified.chrome.timeSource.sha256,
    '0015cb2fa5ee082bb61f07e24c150d161b08a7148143914d43c58f4850c68134'
  );
});

test('keeps the dated display observation separate from the formal predicate', () => {
  const manifest = loadManifest();

  assert.equal(manifest.designTimeObservation.observedOn, '2026-08-15');
  assert.equal(manifest.designTimeObservation.externalDisplayCount, 1);
  assert.deepEqual(manifest.designTimeObservation.externalDisplaySlots, [
    { label: 'LG display', qualification: 'unqualified' }
  ]);
  assert.equal(manifest.qualificationPredicate.externalDisplayCountRequired, 0);
  assert.equal(manifest.qualificationPredicate.releaseDisplayScope, 'built-in-display-only');
  assert.equal(manifest.qualificationPredicate.externalDisplayBehavior, 'excluded-from-release-verdict');
});

test('rejects forbidden identity keys and UUID-shaped values recursively', () => {
  const findings = auditEnvironment({
    safe: {
      rows: [
        { serialNumber: 'redacted' },
        { value: 'BF2C6A3A-E639-51FE-853D-E9CE245A77D6' }
      ]
    }
  });

  assert.deepEqual(findings.map((finding) => finding.id), [
    'PLAN_ENVIRONMENT_PRIVACY',
    'PLAN_ENVIRONMENT_PRIVACY'
  ]);
  assert.deepEqual(auditEnvironment(loadManifest()), []);
});

test('collects the live observation without rewriting the dated observation', async () => {
  const manifestBefore = fs.readFileSync(manifestPath, 'utf8');
  const observation = await collectEnvironment();
  const manifestAfter = fs.readFileSync(manifestPath, 'utf8');

  assert.equal(observation.macOS.version, '26.6.1');
  assert.equal(observation.macOS.build, '25G76');
  assert.equal(observation.chrome.version, '151.0.7922.138');
  assert.equal(observation.displays.builtIn.length, 1);
  assert.equal(Number.isInteger(observation.displays.externalDisplayCount), true);
  assert.equal(observation.externalDisplayCountRequired, 0);
  assert.deepEqual(auditEnvironment(observation), []);
  assert.equal(manifestAfter, manifestBefore);
});
