const PERMITTED_POINTERS = new Set([
  '/identity',
  '/currentLocalEnvironment',
  '/validationScope/runtimeQualifiedEnvironment',
  '/validationScope/claimsExcludedFromThisReleaseVerdict',
  '/authorityArtifacts/chrome-m0-m1-runtime/version',
  '/authorityArtifacts/chrome-m0-m1-runtime/v8',
  '/authorityArtifacts/chrome-m0-m1-runtime/chromiumTagCommit',
  '/authorityArtifacts/chrome-m0-m1-runtime/v8SourceCommit',
  '/authorityArtifacts/chrome-m0-m1-runtime/binarySha256',
  '/normativeDomains/implementationPlan',
  '/machineArtifacts/implementationPlan',
  '/verificationTools/planVerifier',
  '/designClosure/planGovernance'
]);

const escapePointerToken = (value) => String(value).replaceAll('~', '~0').replaceAll('/', '~1');

function rowsBy(rows, key) {
  return Object.fromEntries(
    [...rows]
      .sort((left, right) => String(left[key]).localeCompare(String(right[key]), 'en'))
      .map((row) => [row[key], row])
  );
}

export function normalizeAuthorityRows(value) {
  const normalized = structuredClone(value);
  normalized.authorityArtifacts = rowsBy(normalized.authorityArtifacts ?? [], 'id');
  normalized.normativeDomains = rowsBy(normalized.normativeDomains ?? [], 'domain');
  normalized.machineArtifacts = rowsBy(normalized.machineArtifacts ?? [], 'id');
  normalized.verificationTools = rowsBy(normalized.verificationTools ?? [], 'id');
  return normalized;
}

export function diffLeaves(left, right, pointer = '') {
  if (Object.is(left, right)) return [];

  const leftObject = left !== null && typeof left === 'object';
  const rightObject = right !== null && typeof right === 'object';
  const leftArray = Array.isArray(left);
  const rightArray = Array.isArray(right);

  if (!leftObject || !rightObject || leftArray !== rightArray) {
    return [{ pointer: pointer || '/', left, right }];
  }

  if (leftArray && rightArray) {
    const rows = [];
    const length = Math.max(left.length, right.length);
    for (let index = 0; index < length; index += 1) {
      rows.push(...diffLeaves(left[index], right[index], `${pointer}/${index}`));
    }
    return rows;
  }

  const keys = [...new Set([...Object.keys(left), ...Object.keys(right)])].sort();
  return keys.flatMap((key) => diffLeaves(
    left[key],
    right[key],
    `${pointer}/${escapePointerToken(key)}`
  ));
}

export function isPermittedPointer(pointer, permitted = PERMITTED_POINTERS) {
  return [...permitted].some((prefix) => pointer === prefix || pointer.startsWith(`${prefix}/`));
}

export function compareFrozenScope(g4, g5) {
  return diffLeaves(normalizeAuthorityRows(g4), normalizeAuthorityRows(g5))
    .filter((row) => !isPermittedPointer(row.pointer))
    .map((row) => ({
      id: 'G5_FORBIDDEN_SCOPE_DELTA',
      subject: row.pointer,
      message: `frozen value changed from ${JSON.stringify(row.left)} to ${JSON.stringify(row.right)}`
    }));
}

export const permittedScopeDeltaPointers = Object.freeze([...PERMITTED_POINTERS].sort());
