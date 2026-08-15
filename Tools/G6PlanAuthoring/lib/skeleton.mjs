import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import process from 'node:process';

const NODE_PATH = '/opt/homebrew/Cellar/node/26.7.0/bin/node';
const G5_PARENT_REL = 'docs/contracts/monaco-editor-0.56.0/g5-r';
const DEST_PREFIX = 'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/parent/g5-r/';
const DEST_REL_PREFIX = 'artifacts/parent/g5-r/';
const PATHSPEC_REL = 'Tools/G6PlanAuthoring/parent-snapshot-paths.txt';
const EXPECTED_REVISION = 'G5-R-full-scope-final';
const EXPECTED_CHECKSUM_ROWS = 144;

const sha256File = (file) => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const bytewise = (left, right) =>
  Buffer.compare(Buffer.from(left, 'utf8'), Buffer.from(right, 'utf8'));

function readPathspec(repoRoot) {
  const contents = fs.readFileSync(path.join(repoRoot, PATHSPEC_REL), 'utf8');
  const entries = contents.split('\n').filter((line) => line.length > 0);
  for (const entry of entries) {
    if (!entry.startsWith(DEST_PREFIX)) {
      throw new Error(`G6_SKELETON_PATHSPEC_PREFIX entry=${entry}`);
    }
    if (entry.includes('\0')) {
      throw new Error(`G6_SKELETON_PATHSPEC_NUL entry=${entry}`);
    }
  }
  return entries;
}

function verifyPathConfinement(targetResolved, destinationRelative) {
  const destinationResolved = path.resolve(targetResolved, destinationRelative);
  const relative = path.relative(targetResolved, destinationResolved);
  if (relative === '' || relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`G6_SKELETON_DEST_ESCAPE destination=${destinationRelative}`);
  }
  return destinationResolved;
}

function runEmbeddedVerifier(embeddedRoot) {
  const verifierPath = path.join(embeddedRoot, 'verify-contract.mjs');
  if (!fs.existsSync(verifierPath)) {
    throw new Error('G6_SKELETON_VERIFIER_MISSING');
  }
  const result = spawnSync(NODE_PATH, [verifierPath], {
    cwd: embeddedRoot,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024
  });
  if (result.error) {
    throw new Error(`G6_SKELETON_VERIFIER_ERROR ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(`G6_SKELETON_VERIFIER_FAILED status=${result.status} stderr=${result.stderr.trim()}`);
  }
  let output;
  try {
    output = JSON.parse(result.stdout);
  } catch (error) {
    throw new Error(`G6_SKELETON_VERIFIER_JSON ${error.message}`);
  }
  if (output.adoptedRevision !== EXPECTED_REVISION) {
    throw new Error(`G6_SKELETON_VERIFIER_REVISION actual=${output.adoptedRevision}`);
  }
  if (output.artifactHashesVerified !== EXPECTED_CHECKSUM_ROWS) {
    throw new Error(`G6_SKELETON_VERIFIER_HASHES actual=${output.artifactHashesVerified}`);
  }
  return {
    adoptedRevision: output.adoptedRevision,
    artifactHashesVerified: output.artifactHashesVerified
  };
}

export function copyParentArchive(repoRoot, targetRoot) {
  const pathspec = readPathspec(repoRoot);
  const sourceRoot = path.join(repoRoot, G5_PARENT_REL);
  const targetResolved = path.resolve(repoRoot, targetRoot);
  fs.mkdirSync(targetResolved, { recursive: true });

  const rows = [];
  let totalBytes = 0;
  let mismatches = 0;
  let mode100644 = 0;
  const generatedDestinations = [];

  for (const entry of pathspec) {
    const source = entry.slice(DEST_PREFIX.length);
    const sourceAbs = path.join(sourceRoot, source);
    const destinationRelative = DEST_REL_PREFIX + source;
    const destinationAbs = verifyPathConfinement(targetResolved, destinationRelative);

    // Reject symlinks and special files (lstat does not follow symlinks).
    const sourceStat = fs.lstatSync(sourceAbs);
    if (!sourceStat.isFile()) {
      throw new Error(`G6_SKELETON_SOURCE_NOT_REGULAR source=${source}`);
    }

    fs.mkdirSync(path.dirname(destinationAbs), { recursive: true });
    fs.copyFileSync(sourceAbs, destinationAbs);
    fs.chmodSync(destinationAbs, 0o644);

    const sourceHash = sha256File(sourceAbs);
    const destinationHash = sha256File(destinationAbs);
    if (sourceHash !== destinationHash) mismatches += 1;

    const destinationStat = fs.statSync(destinationAbs);
    const executable = (destinationStat.mode & 0o111) !== 0;
    const gitMode = executable ? '100755' : '100644';
    if (gitMode === '100644') mode100644 += 1;

    const bytes = destinationStat.size;
    totalBytes += bytes;

    rows.push({ source, destination: destinationRelative, sha256: destinationHash, gitMode, bytes });
    generatedDestinations.push(DEST_PREFIX + source);
  }

  rows.sort((left, right) => bytewise(left.source, right.source));

  // Compare the generated destination list with the committed pathspec (bytewise order).
  const sortedGenerated = [...generatedDestinations].sort(bytewise);
  const sortedPathspec = [...pathspec].sort(bytewise);
  if (JSON.stringify(sortedGenerated) !== JSON.stringify(sortedPathspec)) {
    throw new Error('G6_SKELETON_PATHSET_MISMATCH');
  }

  const checksumPath = path.join(targetResolved, DEST_REL_PREFIX, 'SHA256SUMS');
  const checksumContents = fs.readFileSync(checksumPath, 'utf8');
  const checksumRows = checksumContents.endsWith('\n')
    ? checksumContents.slice(0, -1).split('\n').length
    : checksumContents.split('\n').length;

  const embeddedRoot = path.join(targetResolved, DEST_REL_PREFIX);
  const verifier = runEmbeddedVerifier(embeddedRoot);

  return {
    rows,
    bytes: totalBytes,
    checksumRows,
    mode100644,
    mismatches,
    verifier
  };
}

function main() {
  const args = process.argv.slice(2);
  let writeTarget = null;
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--write') {
      i += 1;
      if (i >= args.length) throw new Error('G6_SKELETON_MISSING_VALUE --write');
      writeTarget = args[i];
    } else {
      throw new Error(`G6_SKELETON_UNKNOWN_FLAG ${args[i]}`);
    }
  }
  if (!writeTarget) throw new Error('G6_SKELETON_REQUIRES --write');
  const repoRoot = process.cwd();
  const result = copyParentArchive(repoRoot, writeTarget);
  process.stdout.write(
    `G6_PARENT_SNAPSHOT files=${result.rows.length} bytes=${result.bytes} checksumRows=${result.checksumRows} mode100644=${result.mode100644} mismatches=${result.mismatches}\n`
  );
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main();
}
