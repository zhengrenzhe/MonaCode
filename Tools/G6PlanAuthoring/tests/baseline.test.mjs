import assert from 'node:assert/strict';
import test from 'node:test';
import { buildBaselineInventory } from '../lib/baseline.mjs';

test('captures the exact G5-R execution migration surface', () => {
  const inventory = buildBaselineInventory(process.cwd());
  assert.match(inventory.authoringBaseCommit, /^[0-9a-f]{40}$/);
  assert.equal(inventory.plannedCommitSubjects.length, 35);
  assert.equal(new Set(inventory.plannedCommitSubjects).size, 35);
  assert.equal(inventory.tasks, 200);
  assert.deepEqual(inventory.phaseTaskCounts, {
    '00': 12, '01': 13, '02': 9, '03': 12, '04': 16,
    '05': 77, '06': 10, '07': 11, '08': 10, '09': 30
  });
  assert.deepEqual(inventory.commandTopologies, {
    allSuccess: 5, pipeline: 2, process: 393
  });
  assert.deepEqual(inventory.leafForms, {
    nodeScript: 4, nodeTest: 42, swiftPackage: 2, swiftTest: 359
  });
  assert.equal(inventory.leafProcesses, 407);
  assert.equal(inventory.redScaffoldTasks, 139);
  assert.equal(inventory.redScaffoldPaths, 249);
  assert.equal(inventory.redExitOneWithOneMarker, 200);
  assert.equal(inventory.greenExitZeroWithOneMarker, 200);
  assert.equal(inventory.nodeTestOptionReorders, 20);
  assert.equal(inventory.interfaces, 340);
  assert.equal(inventory.interfaceIDsMentionedOutsidePlan, 40);
  assert.equal(inventory.interfaceIDsOnlyInPlan, 300);
  assert.equal(inventory.contractIdentities, 3582);
  assert.equal(inventory.ownershipRows, 3582);
  assert.equal(inventory.taskOwnershipTokens, 326);
  assert.equal(inventory.createPaths, 314);
  assert.equal(inventory.modifyPaths, 2);
  assert.equal(inventory.testPaths, 198);
  assert.equal(inventory.commitPaths, 512);
  assert.equal(inventory.evidencePaths, 200);
  assert.equal(inventory.g5EvidencePrefixRows, 200);
  assert.equal(inventory.evidencePathsInsideCommitBoundaries, 0);
  assert.equal(inventory.g5TaskCommitMessageFields, 0);
  assert.equal(inventory.g5MarkdownGitCommitCommands, 0);
  assert.equal(inventory.parentFiles, 148);
  assert.equal(inventory.parentBytes, 4050132);
  assert.equal(inventory.parentChecksumRows, 144);
  assert.deepEqual(inventory.parentGitModes, { '100644': 148 });
  assert.deepEqual(inventory.toolchain, {
    architecture: 'arm64',
    bsdtar: { path: '/usr/bin/bsdtar', sha256: 'bc069dd7ef2ecea4c27ff9daa97f4ba4c5a1a41938bad8050e96bce5daa64346', version: '3.5.3', libarchive: '3.7.4' },
    chrome: { path: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', sha256: 'ee37661755341e9fc1babf9c20ec09d6a36e50aa8713ceb08082f8bbe2d8217d', version: '151.0.7922.138', icu: { path: '/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/151.0.7922.138/Resources/icudtl.dat', bytes: 10876560, sha256: '9f48c7f9c7c94d516a14870707e910ab94d75ae640ff6842c4af53276cd26ebe' } },
    git: { path: '/usr/bin/git', sha256: '44a68ddc1983d6cff3fd35ba3f9ba5f82004216f1dcde69892b3d1b06e408698', version: '2.50.1 (Apple Git-155)' },
    macOS: { version: '26.6.1', build: '25G76' },
    node: { path: '/opt/homebrew/Cellar/node/26.7.0/bin/node', sha256: '1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040', version: 'v26.7.0' },
    sandboxExec: { path: '/usr/bin/sandbox-exec', sha256: 'e3d7a792c58a5d3783d2f7274c82d70062393830d8cb1ded713ca554a470bd2f' },
    sdk: { path: '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk', version: '26.5' },
    swift: { path: '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift', sha256: '2ed38571e92c0283091838c1649e27650ad9c99950288e883c7b2dc6c4ce89fb', version: '6.3.3', swiftlang: '6.3.3.1.3', target: 'arm64-apple-macosx26.0' },
    systemProfiler: { path: '/usr/sbin/system_profiler', sha256: '6b868d95b01d44045fc434d5e867cd9ac5de15634fef126522d0a6919ccd2652' },
    xcode: { version: '26.6', build: '17F113' },
    xcrun: { path: '/usr/bin/xcrun', sha256: '4bc0cc7099775fbe35c653ceb09e0e393d2e5ada024db872e0eb8c43500b4dc6' }
  });
});
