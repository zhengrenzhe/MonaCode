import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import process from 'node:process';

const GIT = '/usr/bin/git';
const NODE_PATH = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const PLAN_FILE = 'docs/superpowers/plans/2026-08-15-monacode-g6r-execution-readiness.md';
const G5_PARENT_REL = 'docs/contracts/monaco-editor-0.56.0/g5-r';
const G5_PLAN_MANIFEST = 'monacode-g5r-implementation-plan-manifest.json';
const G5_PARENT_PREFIX = G5_PARENT_REL + '/';
const DEST_PREFIX = 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/';

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const uniqueCount = (rows) => new Set(rows).size;

function execText(cmd, args, opts = {}) {
  return execFileSync(cmd, args, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'], ...opts });
}

function hashFile(p) {
  return sha256(fs.readFileSync(p));
}

function resolveAndHash(p) {
  const resolved = fs.realpathSync(p);
  return sha256(fs.readFileSync(resolved));
}

function resolveCommit(repoRoot, ref) {
  return execText(GIT, ['rev-parse', '--verify', `${ref}^{commit}`], { cwd: repoRoot }).trim();
}

function collectPlannedCommitSubjects(repoRoot) {
  const planPath = path.join(repoRoot, PLAN_FILE);
  const content = fs.readFileSync(planPath, 'utf8');
  const regex = /commit\s+--no-verify\s+--no-gpg-sign\s+-m\s+"([^"]+)"/g;
  const subjects = [];
  let match;
  while ((match = regex.exec(content)) !== null) {
    subjects.push(match[1]);
  }
  if (subjects.length !== 35) throw new Error(`G6_BASELINE_COMMIT_SUBJECTS count=${subjects.length}`);
  if (new Set(subjects).size !== 35) throw new Error('G6_BASELINE_DUPLICATE_SUBJECTS');
  return subjects;
}

function collectRegularFileRows(parentRoot, repoRoot) {
  const output = execFileSync(GIT, ['ls-tree', '-r', '-z', '--full-tree', 'HEAD', '--', G5_PARENT_REL],
    { cwd: repoRoot, encoding: 'utf8' });
  const entries = output.split('\0').filter((e) => e.length > 0);
  const rows = [];
  for (const entry of entries) {
    const tabIdx = entry.indexOf('\t');
    const meta = entry.slice(0, tabIdx);
    const gitPath = entry.slice(tabIdx + 1);
    const parts = meta.split(' ');
    const gitMode = parts[0];
    const gitType = parts[1];
    if (gitType !== 'blob') throw new Error(`G6_BASELINE_PARENT_TYPE path=${gitPath}`);
    if (gitMode !== '100644') throw new Error(`G6_BASELINE_PARENT_MODE path=${gitPath} mode=${gitMode}`);
    if (!gitPath.startsWith(G5_PARENT_PREFIX)) throw new Error(`G6_BASELINE_PARENT_PATH gitPath=${gitPath}`);
    const relativePath = gitPath.slice(G5_PARENT_PREFIX.length);
    const fullPath = path.join(repoRoot, gitPath);
    const stat = fs.statSync(fullPath);
    if (!stat.isFile()) throw new Error(`G6_BASELINE_PARENT_NOT_REGULAR path=${gitPath}`);
    const content = fs.readFileSync(fullPath);
    rows.push({
      relativePath,
      bytes: content.length,
      sha256: sha256(content),
      gitMode
    });
  }
  rows.sort((a, b) => Buffer.compare(Buffer.from(a.relativePath, 'utf8'), Buffer.from(b.relativePath, 'utf8')));
  return rows;
}

function readArtifactCorpusExcludingPlanManifest(artifactsDir) {
  let corpus = '';
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile() && entry.name !== G5_PLAN_MANIFEST) {
        corpus += fs.readFileSync(full, 'utf8');
      }
    }
  }
  walk(artifactsDir);
  return corpus;
}

function countExactGitCommitCommands(root) {
  let count = 0;
  const decoder = new TextDecoder('utf-8', { fatal: true });
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile() && /\.(md|mjs|json)$/.test(entry.name)) {
        const buffer = fs.readFileSync(full);
        const content = decoder.decode(buffer);
        for (const line of content.split('\n')) {
          if (/^\s*git\s+commit(?:\s|$)/.test(line)) {
            count += 1;
          }
        }
      }
    }
  }
  walk(root);
  return count;
}

function collectToolchainLock() {
  const nodeVersion = execText(NODE_PATH, ['--version']).trim();
  const gitVersionRaw = execText(GIT, ['--version']).trim();
  const gitVersion = gitVersionRaw.replace(/^git version /, '');

  const bsdtarPath = '/usr/bin/bsdtar';
  const bsdtarVersionRaw = execText(bsdtarPath, ['--version']).trim();
  const bsdtarVersion = bsdtarVersionRaw.match(/^bsdtar (\S+)/)[1];
  const bsdtarLibarchive = bsdtarVersionRaw.match(/libarchive (\S+)/)[1];

  const xcrunPath = '/usr/bin/xcrun';
  const sandboxExecPath = '/usr/bin/sandbox-exec';
  const systemProfilerPath = '/usr/sbin/system_profiler';

  const swiftPath = '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift';
  const swiftVersionRaw = execText(swiftPath, ['--version']);
  const swiftVersion = swiftVersionRaw.match(/Apple Swift version (\S+)/)[1];
  const swiftSwiftlang = swiftVersionRaw.match(/swiftlang-(\S+)/)[1];
  const swiftTarget = swiftVersionRaw.match(/Target: (\S+)/)[1];

  const macosVersion = execText('/usr/bin/sw_vers', ['-productVersion']).trim();
  const macosBuild = execText('/usr/bin/sw_vers', ['-buildVersion']).trim();

  const xcodeVersionRaw = execText(xcrunPath, ['xcodebuild', '-version']);
  const xcodeVersion = xcodeVersionRaw.match(/Xcode (\S+)/)[1];
  const xcodeBuild = xcodeVersionRaw.match(/Build version (\S+)/)[1];

  const sdkVersion = execText(xcrunPath, ['--show-sdk-version']).trim();
  const sdkPath = `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${sdkVersion}.sdk`;

  const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const chromeVersionRaw = execText(chromePath, ['--version']).trim();
  const chromeVersion = chromeVersionRaw.match(/Google Chrome (\S+)/)[1];
  const chromeIcuPath = `/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/${chromeVersion}/Resources/icudtl.dat`;
  const chromeIcuBytes = fs.statSync(chromeIcuPath).size;
  const chromeIcuSha256 = hashFile(chromeIcuPath);

  return {
    architecture: process.arch,
    bsdtar: { path: bsdtarPath, sha256: hashFile(bsdtarPath), version: bsdtarVersion, libarchive: bsdtarLibarchive },
    chrome: {
      path: chromePath,
      sha256: hashFile(chromePath),
      version: chromeVersion,
      icu: { path: chromeIcuPath, bytes: chromeIcuBytes, sha256: chromeIcuSha256 }
    },
    git: { path: GIT, sha256: hashFile(GIT), version: gitVersion },
    macOS: { version: macosVersion, build: macosBuild },
    node: { path: NODE_PATH, sha256: resolveAndHash(NODE_PATH), version: nodeVersion },
    sandboxExec: { path: sandboxExecPath, sha256: hashFile(sandboxExecPath) },
    sdk: { path: sdkPath, version: sdkVersion },
    swift: {
      path: swiftPath,
      sha256: hashFile(swiftPath),
      version: swiftVersion,
      swiftlang: swiftSwiftlang,
      target: swiftTarget
    },
    systemProfiler: { path: systemProfilerPath, sha256: hashFile(systemProfilerPath) },
    xcode: { version: xcodeVersion, build: xcodeBuild },
    xcrun: { path: xcrunPath, sha256: hashFile(xcrunPath) }
  };
}

export function buildBaselineInventory(repoRoot) {
  const manifestPath = path.join(repoRoot, G5_PARENT_REL, 'artifacts', G5_PLAN_MANIFEST);
  const parentRoot = path.join(repoRoot, G5_PARENT_REL);
  const bytes = fs.readFileSync(manifestPath);
  const plan = JSON.parse(bytes);
  const parentRows = collectRegularFileRows(parentRoot, repoRoot);
  const tasks = plan.tasks;
  const commands = tasks.flatMap((task) => ['red', 'green'].flatMap(
    (stage) => task[stage].map((row) => row.run)
  ));
  const leafForm = (run) => run.startsWith('swift test ') ? 'swiftTest'
    : run === 'swift package dump-package' ? 'swiftPackage'
    : run.startsWith('node --test ') ? 'nodeTest'
    : run.startsWith('node ') ? 'nodeScript'
    : 'invalid';
  const parse = (run) => {
    if (run.includes(' && ')) return { topology: 'allSuccess', leaves: run.split(' && ') };
    if (run.includes(' | ')) return { topology: 'pipeline', leaves: run.split(' | ') };
    return { topology: 'process', leaves: [run] };
  };
  const parsed = commands.map(parse);
  const leaves = parsed.flatMap((row) => row.leaves);
  const interfaceIDs = [...new Set(tasks.flatMap((task) => task.interfaces.produces))].sort();
  const artifactCorpus = readArtifactCorpusExcludingPlanManifest(path.join(parentRoot, 'artifacts'));
  const isIdentifierByte = (value) => value !== undefined && /[A-Za-z0-9_]/.test(value);
  const containsExactIdentifier = (corpus, id) => {
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(id)) return corpus.includes(id);
    for (let offset = 0; ; offset += 1) {
      const index = corpus.indexOf(id, offset);
      if (index === -1) return false;
      if (!isIdentifierByte(corpus[index - 1]) && !isIdentifierByte(corpus[index + id.length])) return true;
      offset = index;
    }
  };
  const interfaceCoverage = {
    mentioned: interfaceIDs.filter((id) => containsExactIdentifier(artifactCorpus, id)),
    absent: interfaceIDs.filter((id) => !containsExactIdentifier(artifactCorpus, id))
  };
  const redScaffoldTasks = tasks.filter((task) => task.red.some((row) => row.run.startsWith('swift test '))
    && task.files.create.some((p) => p.startsWith('Sources/') && p.endsWith('.swift')));
  if (leaves.some((run) => leafForm(run) === 'invalid')) throw new Error('G6_BASELINE_COMMAND_FORM');
  const countBy = (rows, kinds, classify) => Object.fromEntries(kinds.map((kind) => [
    kind, rows.filter((row) => classify(row) === kind).length
  ]));
  return {
    authoringBaseCommit: resolveCommit(repoRoot, 'HEAD'),
    plannedCommitSubjects: collectPlannedCommitSubjects(repoRoot),
    planSha256: sha256(bytes),
    tasks: tasks.length,
    commands: commands.length,
    phaseTaskCounts: Object.fromEntries([...new Set(tasks.map((task) => task.phase))].sort()
      .map((phase) => [phase, tasks.filter((task) => task.phase === phase).length])),
    commandTopologies: countBy(parsed, ['allSuccess', 'pipeline', 'process'], (row) => row.topology),
    leafForms: countBy(leaves, ['nodeScript', 'nodeTest', 'swiftPackage', 'swiftTest'], leafForm),
    leafProcesses: leaves.length,
    redScaffoldTasks: redScaffoldTasks.length,
    redScaffoldPaths: redScaffoldTasks.flatMap((task) => task.files.create
      .filter((p) => p.startsWith('Sources/') && p.endsWith('.swift'))).length,
    redExitOneWithOneMarker: tasks.flatMap((task) => task.red)
      .filter((row) => row.expectedExit === 1 && row.expectedOutputIncludes.length === 1).length,
    greenExitZeroWithOneMarker: tasks.flatMap((task) => task.green)
      .filter((row) => row.expectedExit === 0 && row.expectedOutputIncludes.length === 1).length,
    nodeTestOptionReorders: leaves.filter((run) => /^node --test \S+ --test-name-pattern \S+$/.test(run)).length,
    interfaces: uniqueCount(tasks.flatMap((task) => [
      ...task.interfaces.produces, ...task.interfaces.consumes
    ])),
    interfaceIDsMentionedOutsidePlan: interfaceCoverage.mentioned.length,
    interfaceIDsOnlyInPlan: interfaceCoverage.absent.length,
    contractIdentities: plan.ownership.length,
    ownershipRows: plan.ownership.length,
    taskOwnershipTokens: tasks.flatMap((task) => task.ownership).length,
    createPaths: uniqueCount(tasks.flatMap((task) => task.files.create)),
    modifyPaths: uniqueCount(tasks.flatMap((task) => task.files.modify)),
    testPaths: uniqueCount(tasks.flatMap((task) => task.files.test)),
    commitPaths: uniqueCount(tasks.flatMap((task) => task.commitBoundary)),
    evidencePaths: uniqueCount(tasks.flatMap((task) => task.evidence)),
    g5EvidencePrefixRows: tasks.flatMap((task) => task.evidence)
      .filter((p) => p.startsWith('artifacts/acceptance-evidence/g5-r/')).length,
    evidencePathsInsideCommitBoundaries: tasks.reduce((count, task) => count
      + task.evidence.filter((p) => task.commitBoundary.includes(p)).length, 0),
    g5TaskCommitMessageFields: tasks.filter((task) => Object.hasOwn(task, 'commitMessage')).length,
    g5MarkdownGitCommitCommands: countExactGitCommitCommands(path.join(parentRoot, 'implementation-plan')),
    toolchain: collectToolchainLock(),
    parentFiles: parentRows.length,
    parentBytes: parentRows.reduce((sum, row) => sum + row.bytes, 0),
    parentGitModes: countBy(parentRows, ['100644'], (row) => row.gitMode),
    parentChecksumRows: fs.readFileSync(path.join(parentRoot, 'SHA256SUMS'), 'utf8')
      .trim().split('\n').length
  };
}

function validateOutputPath(p, repoRoot, seenPaths) {
  if (p.includes('\n') || p.includes('\0')) {
    throw new Error('G6_BASELINE_PATH_NEWLINE_NUL');
  }
  if (/[:!?*\[\\~^]/.test(p)) {
    throw new Error('G6_BASELINE_PATHSPEC_MAGIC');
  }
  if (seenPaths.has(p)) {
    throw new Error('G6_BASELINE_DUPLICATE_PATH');
  }
  seenPaths.add(p);
  const resolved = path.resolve(repoRoot, p);
  const rel = path.relative(repoRoot, resolved);
  if (rel.startsWith('..') || path.isAbsolute(rel)) {
    throw new Error('G6_BASELINE_PATH_OUTSIDE_REPO');
  }
  return resolved;
}

function writeInventory(inventory, outPath) {
  const json = JSON.stringify(inventory, null, 2) + '\n';
  fs.writeFileSync(outPath, json);
}

function writeParentPathspec(parentRows, outPath) {
  const lines = parentRows.map((row) => DEST_PREFIX + row.relativePath);
  fs.writeFileSync(outPath, lines.join('\n') + '\n');
}

function verifyAuthoringRange(repoRoot) {
  const status = execText(GIT, ['status', '--porcelain=v1'], { cwd: repoRoot });
  if (status.trim() !== '') {
    throw new Error('G6_BASELINE_RANGE_NOT_CLEAN');
  }
  const inventoryPath = path.join(repoRoot, 'Tools/G6PlanAuthoring/baseline-inventory.json');
  const inventory = JSON.parse(fs.readFileSync(inventoryPath, 'utf8'));
  const base = inventory.authoringBaseCommit;
  const head = resolveCommit(repoRoot, 'HEAD');
  const range = `${base}..${head}`;
  const commitCount = parseInt(
    execText(GIT, ['rev-list', '--count', range], { cwd: repoRoot }).trim(), 10
  );
  const plannedCommits = inventory.plannedCommitSubjects.length;
  if (commitCount !== plannedCommits) {
    throw new Error(`G6_BASELINE_RANGE_COUNT expected=${plannedCommits} actual=${commitCount}`);
  }
  const subjects = execText(GIT, ['log', '--format=%s', range], { cwd: repoRoot })
    .trim().split('\n');
  for (let i = 0; i < plannedCommits; i++) {
    if (subjects[i] !== inventory.plannedCommitSubjects[i]) {
      throw new Error(`G6_BASELINE_RANGE_SUBJECT index=${i} expected="${inventory.plannedCommitSubjects[i]}" actual="${subjects[i]}"`);
    }
  }
  const authors = new Set(execText(GIT, ['log', '--format=%an <%ae>', range], { cwd: repoRoot })
    .trim().split('\n'));
  const committers = new Set(execText(GIT, ['log', '--format=%cn <%ce>', range], { cwd: repoRoot })
    .trim().split('\n'));
  const expectedIdentity = 'zhengrenzhe <zhengrenzhe0416@outlook.com>';
  for (const a of authors) {
    if (a !== expectedIdentity) throw new Error(`G6_BASELINE_RANGE_AUTHOR identity=${a}`);
  }
  for (const c of committers) {
    if (c !== expectedIdentity) throw new Error(`G6_BASELINE_RANGE_COMMITTER identity=${c}`);
  }
  let resolutionCommits = 0;
  const catalogPath = path.join(repoRoot, 'Tools/G6PlanAuthoring/adversarial-catalog.json');
  if (fs.existsSync(catalogPath)) {
    const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
    function countResolutionCommits(obj) {
      if (obj === null || typeof obj !== 'object') return;
      if (Array.isArray(obj)) {
        for (const item of obj) countResolutionCommits(item);
        return;
      }
      if (Object.prototype.hasOwnProperty.call(obj, 'resolutionCommit')) {
        if (obj.resolutionCommit !== null) resolutionCommits += 1;
      }
      for (const v of Object.values(obj)) countResolutionCommits(v);
    }
    countResolutionCommits(catalog);
  }
  if (resolutionCommits > 0) {
    throw new Error(`G6_BASELINE_RESOLUTION_COMMIT_NON_NULL count=${resolutionCommits}`);
  }
  let whitespaceErrors = 0;
  try {
    execText(GIT, ['diff', '--check', range], { cwd: repoRoot });
  } catch (e) {
    const output = (e.stdout || '').toString();
    whitespaceErrors = output.trim() ? output.trim().split('\n').length : 0;
  }
  const totalCommits = plannedCommits + resolutionCommits;
  process.stdout.write(
    `G6_AUTHORING_RANGE plannedCommits=${plannedCommits} resolutionCommits=${resolutionCommits} totalCommits=${totalCommits} authors=${authors.size} committers=${committers.size} whitespaceErrors=${whitespaceErrors}\n`
  );
}

function observeDisplay() {
  const raw = execFileSync('/usr/sbin/system_profiler', ['SPDisplaysDataType', '-json'], { encoding: 'utf8' });
  const data = JSON.parse(raw);
  const displays = data.SPDisplaysDataType || [];
  let online = 0;
  let internal = 0;
  const names = [];
  for (const item of displays) {
    const itemDisplays = item.spdisplays_ndrvs || [];
    for (const d of itemDisplays) {
      const isOnline = d.spdisplays_online === 'spdisplays_yes';
      const isInternal = d.spdisplays_connection_type === 'spdisplays_internal';
      if (isOnline) {
        online += 1;
        names.push(d._name || '');
      }
      if (isInternal) internal += 1;
    }
  }
  const result = {
    online,
    internal,
    external: online - internal,
    names: names.sort()
  };
  process.stdout.write(JSON.stringify(result, null, 2) + '\n');
}

function main() {
  const args = process.argv.slice(2);
  let writeInventoryPath = null;
  let writeParentPathspecPath = null;
  let verifyRange = false;
  let observe = false;
  const seenPaths = new Set();
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--write-inventory') {
      i += 1;
      if (i >= args.length) throw new Error('G6_BASELINE_MISSING_VALUE --write-inventory');
      writeInventoryPath = validateOutputPath(args[i], process.cwd(), seenPaths);
    } else if (arg === '--write-parent-pathspec') {
      i += 1;
      if (i >= args.length) throw new Error('G6_BASELINE_MISSING_VALUE --write-parent-pathspec');
      writeParentPathspecPath = validateOutputPath(args[i], process.cwd(), seenPaths);
    } else if (arg === '--verify-authoring-range') {
      verifyRange = true;
    } else if (arg === '--observe-display') {
      observe = true;
    } else {
      throw new Error(`G6_BASELINE_UNKNOWN_FLAG ${arg}`);
    }
  }
  const repoRoot = process.cwd();
  if (verifyRange) {
    verifyAuthoringRange(repoRoot);
    return;
  }
  if (observe) {
    observeDisplay();
    return;
  }
  const inventory = buildBaselineInventory(repoRoot);
  if (writeInventoryPath) {
    writeInventory(inventory, writeInventoryPath);
  }
  if (writeParentPathspecPath) {
    const parentRoot = path.join(repoRoot, G5_PARENT_REL);
    const parentRows = collectRegularFileRows(parentRoot, repoRoot);
    writeParentPathspec(parentRows, writeParentPathspecPath);
  }
  if (writeInventoryPath || writeParentPathspecPath) {
    const parentMode100644 = inventory.parentGitModes['100644'] || 0;
    process.stdout.write(
      `G6_BASELINE tasks=${inventory.tasks} commands=${inventory.commands} leaves=${inventory.leafProcesses} parentFiles=${inventory.parentFiles} parentBytes=${inventory.parentBytes} parentMode100644=${parentMode100644} toolchain=locked\n`
    );
  }
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main();
}
