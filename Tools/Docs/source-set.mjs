import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

export const SOURCE_ROOTS = [
  'Package.swift',
  'Sources',
  'Tests',
  'Tools',
  'Comparators',
];

export const G6_MANIFEST =
  'docs/contracts/monaco-editor-0.56.0/g6-r/artifacts/monacode-g6r-authoritative-manifest.json';

const compareUTF8 = (left, right) =>
  Buffer.compare(Buffer.from(left, 'utf8'), Buffer.from(right, 'utf8'));

export const sha256 = (bytes) =>
  createHash('sha256').update(bytes).digest('hex');

export function computeVerificationSourceSet(repoRoot) {
  const listed = execFileSync(
    '/usr/bin/git',
    ['ls-files', '-z', '--', ...SOURCE_ROOTS],
    { cwd: repoRoot },
  );
  const paths = listed
    .toString('utf8')
    .split('\0')
    .filter(Boolean)
    .sort(compareUTF8);

  const digest = createHash('sha256');
  const rows = paths.map((path) => {
    const bytes = readFileSync(resolve(repoRoot, path));
    digest
      .update(path, 'utf8')
      .update('\0')
      .update(String(bytes.length), 'utf8')
      .update('\0')
      .update(bytes);
    return {
      path,
      bytes: bytes.length,
      sha256: sha256(bytes),
    };
  });

  const g6Bytes = readFileSync(resolve(repoRoot, G6_MANIFEST));
  const g6ManifestDigest = sha256(g6Bytes);
  digest
    .update('g6-r-manifest', 'utf8')
    .update('\0')
    .update(g6ManifestDigest, 'utf8');

  return {
    digest: digest.digest('hex'),
    rows,
    g6ManifestDigest,
  };
}
